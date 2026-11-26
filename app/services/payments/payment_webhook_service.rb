# frozen_string_literal: true

module Payments
  # Payment events pushed by the gateways to POST /api/v1/payments/webhooks/:gateway.
  #
  # The gateways are simulated, so one signing scheme serves them all: the X-Webhook-Signature
  # header carries "sha256=" and the hex HMAC-SHA256 of the raw request body, keyed with the
  # gateway's secret (STRIPE_WEBHOOK_SECRET, PAYPAL_WEBHOOK_SECRET). Without a secret every event is
  # refused. Real gateways sign differently and should be verified with their own SDK.
  #
  # Each event is applied at most once (payment_webhook_events) and never moves a payment back:
  # a failure does not undo a completed payment.
  class PaymentWebhookService
    # Where each gateway puts the event type and the payment's transaction id, and which events
    # mean what. Payloads follow the shape of the real gateways' events.
    GATEWAYS = {
      'stripe' => {
        event_type: %w[type], transaction_id: %w[data object id],
        events: { 'payment_intent.succeeded' => :succeeded, 'payment_intent.payment_failed' => :failed,
                  'charge.dispute.created' => :disputed }
      },
      'paypal' => {
        event_type: %w[event_type], transaction_id: %w[resource id],
        events: { 'PAYMENT.SALE.COMPLETED' => :succeeded, 'PAYMENT.SALE.DENIED' => :failed,
                  'CUSTOMER.DISPUTE.CREATED' => :disputed }
      }
    }.freeze

    class << self
      # @return [Hash] { status: HTTP status symbol, body: Hash }
      def receive(gateway:, raw_body:, signature:)
        config = GATEWAYS[gateway]
        return reply(:not_found, error: 'Unknown gateway') unless config

        secret = ENV.fetch("#{gateway.upcase}_WEBHOOK_SECRET", nil)
        return reply(:service_unavailable, error: 'Webhook secret not configured') if secret.blank?
        return reply(:unauthorized, error: 'Invalid signature') unless valid_signature?(raw_body, signature, secret)

        apply(gateway, config, JSON.parse(raw_body))
      rescue JSON::ParserError
        reply(:bad_request, error: 'Invalid JSON')
      end

      private

      def valid_signature?(raw_body, signature, secret)
        expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"
        signature.present? && ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end

      def apply(gateway, config, event)
        event_id = event['id'].to_s
        return reply(:bad_request, error: 'Event id is missing') if event_id.blank?

        event_type = event.dig(*config[:event_type])
        action = config[:events][event_type]
        return reply(:ok, ignored: "Unhandled event: #{event_type}") unless action

        payment = find_payment(gateway, event.dig(*config[:transaction_id]))
        return reply(:not_found, error: 'Payment not found') unless payment

        # requires_new: a duplicate rolls back to its own savepoint, not an outer transaction.
        PaymentWebhookEvent.transaction(requires_new: true) do
          PaymentWebhookEvent.create!(gateway: gateway, event_id: event_id, event_type: event_type, payment: payment)
          send(action, payment, event_id)
        end
        reply(:ok, processed: true)
      rescue ActiveRecord::RecordNotUnique
        reply(:ok, duplicate: true)
      end

      def find_payment(gateway, transaction_id)
        return if transaction_id.blank?

        Payment.joins(:payment_method).find_by(transaction_id: transaction_id,
                                               payment_methods: { gateway_type: gateway })
      end

      # The callbacks on Payment keep the order's payment_status in step.
      def succeeded(payment, _event_id)
        return unless %w[pending processing failed].include?(payment.status)

        payment.update!(status: 'completed', processed_at: Time.current)
      end

      def failed(payment, _event_id)
        return unless %w[pending processing].include?(payment.status)

        payment.update!(status: 'failed', failure_reason: 'Declined by the gateway', processed_at: Time.current)
      end

      # A dispute is not lost yet, so the payment keeps its status; the dispute is recorded on it.
      def disputed(payment, event_id)
        dispute = { 'event_id' => event_id, 'opened_at' => Time.current.iso8601 }
        payment.update!(metadata: (payment.metadata || {}).merge('dispute' => dispute))
      end

      def reply(status, **body)
        { status: status, body: body }
      end
    end
  end
end
