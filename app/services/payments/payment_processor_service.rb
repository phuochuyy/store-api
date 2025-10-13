# frozen_string_literal: true

module Payments
  class PaymentProcessorService
    class << self
      # Process a payment for an order
      # @param order [Order] The order to process payment for
      # @param payment_method [PaymentMethod] The payment method to use
      # @param payment_data [Hash] Additional payment data (card details, etc.)
      # @return [Hash] Result with success status and payment information
      def process_payment(order:, payment_method:, payment_data: {})
        PaymentProcessingCoreService.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )
      end

      # Refund a payment
      # @param payment [Payment] The payment to refund
      # @param amount [Decimal] Amount to refund (nil for full refund)
      # @param reason [String] Reason for refund
      # @return [Hash] Result with success status
      def refund_payment(payment:, amount: nil, reason: nil)
        PaymentProcessingCoreService.refund_payment(
          payment: payment,
          amount: amount,
          reason: reason
        )
      end

      # Process webhook from payment gateway
      # @param gateway_type [String] Type of payment gateway
      # @param payload [Hash] Webhook payload
      # @param signature [String] Webhook signature for verification
      # @return [Hash] Processing result
      def process_webhook(gateway_type:, payload:, signature: nil)
        PaymentWebhookService.process_webhook(
          gateway_type: gateway_type,
          payload: payload,
          signature: signature
        )
      end

      # Process Stripe webhook
      # @param payload [Hash] Stripe webhook payload
      # @param signature [String] Stripe signature
      # @return [Hash] Processing result
      def process_stripe_webhook(payload:, signature:)
        PaymentWebhookService.process_stripe_webhook(payload: payload, signature: signature)
      end

      # Process PayPal webhook
      # @param payload [Hash] PayPal webhook payload
      # @param signature [String] PayPal signature
      # @return [Hash] Processing result
      def process_paypal_webhook(payload:, signature:)
        PaymentWebhookService.process_paypal_webhook(payload: payload, signature: signature)
      end

      # Process Square webhook
      # @param payload [Hash] Square webhook payload
      # @param signature [String] Square signature
      # @return [Hash] Processing result
      def process_square_webhook(payload:, signature:)
        PaymentWebhookService.process_square_webhook(payload: payload, signature: signature)
      end

      # Get payment processing statistics
      # @param period [String] Time period for statistics
      # @return [Hash] Processing statistics
      def get_processing_statistics(period = 'month')
        start_date = calculate_start_date(period)
        payments = Payment.where(created_at: start_date..)

        {
          total_payments: payments.count,
          successful_payments: payments.successful.count,
          failed_payments: payments.failed.count,
          refunded_payments: payments.refunded.count,
          total_amount: payments.successful.sum(:amount),
          total_fees: calculate_total_fees(payments),
          success_rate: calculate_success_rate(payments),
          average_processing_time: calculate_average_processing_time(payments),
          period: period,
          start_date: start_date,
          end_date: Time.current
        }
      end

      # Get payment method performance
      # @param period [String] Time period for analysis
      # @return [Hash] Payment method performance data
      def get_payment_method_performance(period = 'month')
        start_date = calculate_start_date(period)

        PaymentMethod.active.includes(:payments).map do |pm|
          payments = pm.payments.where(created_at: start_date..)
          {
            payment_method_id: pm.id,
            name: pm.name,
            gateway_type: pm.gateway_type,
            total_transactions: payments.count,
            successful_transactions: payments.successful.count,
            total_amount: payments.successful.sum(:amount),
            success_rate: calculate_success_rate(payments),
            average_amount: calculate_average_amount(payments.successful)
          }
        end.sort_by { |data| -data[:total_amount] }
      end

      private

      def calculate_start_date(period)
        case period
        when 'day'
          1.day.ago
        when 'week'
          1.week.ago
        when 'year'
          1.year.ago
        else
          1.month.ago
        end
      end

      def calculate_total_fees(payments)
        payments.successful.sum do |payment|
          if payment.payment_method.fee_percentage
            (payment.amount * payment.payment_method.fee_percentage / 100)
          else
            0
          end
        end
      end

      def calculate_success_rate(payments)
        return 0 if payments.empty?

        (payments.successful.count.to_f / payments.count * 100).round(2)
      end

      def calculate_average_processing_time(payments)
        successful_payments = payments.successful.where.not(processed_at: nil)
        return 0 if successful_payments.empty?

        total_time = successful_payments.sum do |payment|
          (payment.processed_at - payment.created_at).to_f
        end

        (total_time / successful_payments.count).round(2)
      end

      def calculate_average_amount(payments)
        return 0 if payments.empty?

        (payments.sum(:amount) / payments.count.to_f).round(2)
      end
    end
  end
end
