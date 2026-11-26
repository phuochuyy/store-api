# frozen_string_literal: true

module Payments
  # Gives money back when a paid order is cancelled or a return is completed. Online payments are
  # refunded through their gateway. Offline ones (cash on delivery, bank transfer) have no gateway,
  # so money already collected is left to be refunded by hand, and the caller is told so.
  class OrderRefundService
    class RefundError < StandardError; end

    MANUAL_REFUND_NOTE = 'refund by hand: the payment was collected offline'

    class << self
      # Withdraws pending payments and refunds every completed online payment in full.
      # @return [String, nil] MANUAL_REFUND_NOTE when collected offline money must be refunded by hand
      def refund_cancelled_order(order)
        order.payments.pending.find_each { |payment| payment.mark_as_cancelled!(reason: 'Order cancelled') }

        manual = false
        order.payments.successful.find_each do |payment|
          next manual = true if payment.payment_method.offline?

          refund!(payment, payment.amount, 'Order cancelled')
        end
        MANUAL_REFUND_NOTE if manual
      end

      # Refunds the return's amount on the order's latest completed payment.
      # @return [String, nil] MANUAL_REFUND_NOTE when that payment was collected offline
      def refund_return(return_request)
        amount = return_request.refund_amount.to_d
        return if amount <= 0

        payment = return_request.order.payments.successful.order(:created_at).last
        return unless payment # nothing was paid, so there is nothing to give back
        return MANUAL_REFUND_NOTE if payment.payment_method.offline?

        refund!(payment, amount, "Return ##{return_request.id}")
        nil
      end

      private

      def refund!(payment, amount, reason)
        result = PaymentProcessingCoreService.refund_payment(payment: payment, amount: amount, reason: reason)
        raise RefundError, "Refund failed: #{result[:error]}" unless result[:success]
      end
    end
  end
end
