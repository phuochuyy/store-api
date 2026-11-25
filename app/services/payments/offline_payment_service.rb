# frozen_string_literal: true

module Payments
  # Cash on delivery and bank transfers are paid outside the app, so there is no gateway to
  # settle them: PaymentProcessingCoreService records the payment as pending, and an admin
  # confirms here that the money arrived.
  class OfflinePaymentService
    class << self
      # The order is locked so that two confirmations cannot both go through.
      # @param payment [Payment] A pending payment with an offline payment method
      # @param confirmed_by [User] The admin confirming it
      # @return [Hash] Result with success status
      def confirm(payment:, confirmed_by:)
        error = payment.order.with_lock { complete(payment, confirmed_by) }
        return { success: false, error: error } if error

        { success: true, payment: payment, message: 'Payment confirmed' }
      end

      private

      # Runs under the order's lock. Returns an error message, or nil once the payment is completed
      # (which marks the order paid, see Payment#sync_order_payment_status).
      def complete(payment, confirmed_by)
        payment.reload
        confirmable = payment.pending? && payment.payment_method.offline?
        return 'Only pending offline payments can be confirmed' unless confirmable
        return 'Order cannot be paid' unless payment.order.can_be_paid?

        payment.update!(
          status: 'completed',
          processed_at: Time.current,
          metadata: (payment.metadata || {}).merge('confirmed_by' => confirmed_by.id)
        )
        nil
      end
    end
  end
end
