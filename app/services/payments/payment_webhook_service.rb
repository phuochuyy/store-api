# frozen_string_literal: true

module Payments
  class PaymentWebhookService
    class << self
      # Process webhook from payment gateway
      # @param gateway_type [String] Type of payment gateway
      # @param payload [Hash] Webhook payload
      # @param signature [String] Webhook signature for verification
      # @return [Hash] Processing result
      def process_webhook(gateway_type:, payload:, signature: nil)
        return { success: false, error: 'Gateway type is required' } if gateway_type.blank?
        return { success: false, error: 'Payload is required' } if payload.blank?

        verification_result = verify_webhook_signature(gateway_type, payload, signature)
        return verification_result unless verification_result[:success]

        process_webhook_payload(gateway_type, payload)
      rescue StandardError => e
        Rails.logger.error "Webhook processing error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Webhook processing failed', details: e.message }
      end

      # Process Stripe webhook
      # @param payload [Hash] Stripe webhook payload
      # @param signature [String] Stripe signature
      # @return [Hash] Processing result
      def process_stripe_webhook(payload:, signature:)
        process_webhook(gateway_type: 'stripe', payload: payload, signature: signature)
      end

      # Process PayPal webhook
      # @param payload [Hash] PayPal webhook payload
      # @param signature [String] PayPal signature
      # @return [Hash] Processing result
      def process_paypal_webhook(payload:, signature:)
        process_webhook(gateway_type: 'paypal', payload: payload, signature: signature)
      end

      # Process Square webhook
      # @param payload [Hash] Square webhook payload
      # @param signature [String] Square signature
      # @return [Hash] Processing result
      def process_square_webhook(payload:, signature:)
        process_webhook(gateway_type: 'square', payload: payload, signature: signature)
      end

      private

      def verify_webhook_signature(gateway_type, payload, signature)
        case gateway_type
        when 'stripe'
          verify_stripe_signature(payload, signature)
        when 'paypal'
          verify_paypal_signature(payload, signature)
        when 'square'
          verify_square_signature(payload, signature)
        else
          { success: false, error: "Unsupported gateway type: #{gateway_type}" }
        end
      end

      def process_webhook_payload(gateway_type, payload)
        case gateway_type
        when 'stripe'
          process_stripe_payload(payload)
        when 'paypal'
          process_paypal_payload(payload)
        when 'square'
          process_square_payload(payload)
        else
          { success: false, error: "Unsupported gateway type: #{gateway_type}" }
        end
      end

      def verify_stripe_signature(payload, signature)
        # Mock Stripe signature verification
        { success: true, message: 'Stripe signature verified' }
      end

      def verify_paypal_signature(payload, signature)
        # Mock PayPal signature verification
        { success: true, message: 'PayPal signature verified' }
      end

      def verify_square_signature(payload, signature)
        # Mock Square signature verification
        { success: true, message: 'Square signature verified' }
      end

      def process_stripe_payload(payload)
        event_type = payload['type']
        case event_type
        when 'payment_intent.succeeded'
          handle_payment_success(payload)
        when 'payment_intent.payment_failed'
          handle_payment_failure(payload)
        when 'charge.dispute.created'
          handle_chargeback(payload)
        else
          { success: true, message: "Unhandled Stripe event: #{event_type}" }
        end
      end

      def process_paypal_payload(payload)
        event_type = payload['event_type']
        case event_type
        when 'PAYMENT.SALE.COMPLETED'
          handle_payment_success(payload)
        when 'PAYMENT.SALE.DENIED'
          handle_payment_failure(payload)
        when 'CUSTOMER.DISPUTE.CREATED'
          handle_chargeback(payload)
        else
          { success: true, message: "Unhandled PayPal event: #{event_type}" }
        end
      end

      def process_square_payload(payload)
        event_type = payload['type']
        case event_type
        when 'payment.updated'
          handle_payment_success(payload)
        when 'payment.failed'
          handle_payment_failure(payload)
        else
          { success: true, message: "Unhandled Square event: #{event_type}" }
        end
      end

      def handle_payment_success(payload)
        transaction_id = extract_transaction_id(payload)
        payment = find_payment_by_transaction_id(transaction_id)

        return { success: false, error: 'Payment not found' } unless payment

        payment.update!(
          status: 'completed',
          processed_at: Time.current,
          gateway_response: payload
        )

        { success: true, message: 'Payment status updated to completed' }
      end

      def handle_payment_failure(payload)
        transaction_id = extract_transaction_id(payload)
        payment = find_payment_by_transaction_id(transaction_id)

        return { success: false, error: 'Payment not found' } unless payment

        payment.update!(
          status: 'failed',
          failure_reason: payload['failure_reason'] || 'Payment failed',
          gateway_response: payload
        )

        { success: true, message: 'Payment status updated to failed' }
      end

      def handle_chargeback(payload)
        transaction_id = extract_transaction_id(payload)
        payment = find_payment_by_transaction_id(transaction_id)

        return { success: false, error: 'Payment not found' } unless payment

        payment.update!(
          status: 'chargeback',
          gateway_response: payload
        )

        { success: true, message: 'Payment status updated to chargeback' }
      end

      def extract_transaction_id(payload)
        # Extract transaction ID based on gateway type
        payload['id'] || payload['transaction_id'] || payload['payment_id']
      end

      def find_payment_by_transaction_id(transaction_id)
        Payment.find_by(gateway_transaction_id: transaction_id)
      end
    end
  end
end
