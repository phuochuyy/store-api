# frozen_string_literal: true

module Payments
  class PaymentProcessingCoreService
    class << self
      # Process a payment for an order
      # @param order [Order] The order to process payment for
      # @param payment_method [PaymentMethod] The payment method to use
      # @param payment_data [Hash] Additional payment data (card details, etc.)
      # @return [Hash] Result with success status and payment information
      def process_payment(order:, payment_method:, payment_data: {})
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'Payment method not found' } unless payment_method
        return { success: false, error: 'Order cannot be paid' } unless order.can_be_paid?
        return { success: false, error: 'Payment method is not active' } unless payment_method.is_active?

        total_amount = payment_method.total_amount_with_fees(order.total_amount)
        payment = create_payment_record(order, payment_method, total_amount, payment_data)
        result = process_with_gateway(payment, payment_data)
        update_payment_status(payment, result)

        result
      rescue StandardError => e
        Rails.logger.error "Payment processing error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Payment processing failed', details: e.message }
      end

      # Refund a payment
      # @param payment [Payment] The payment to refund
      # @param amount [Decimal] Amount to refund (nil for full refund)
      # @param reason [String] Reason for refund
      # @return [Hash] Result with success status
      def refund_payment(payment:, amount: nil, reason: nil)
        return { success: false, error: 'Payment not found' } unless payment
        return { success: false, error: 'Payment cannot be refunded' } unless payment.can_be_refunded?

        refund_amount = amount || payment.amount
        return { success: false, error: 'Refund amount exceeds payment amount' } if refund_amount > payment.amount

        result = process_refund_with_gateway(payment, refund_amount, reason)
        update_refund_status(payment, result, refund_amount, reason)

        result
      rescue StandardError => e
        Rails.logger.error "Payment refund error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Payment refund failed', details: e.message }
      end

      private

      def create_payment_record(order, payment_method, total_amount, payment_data)
        Payment.create!(
          order: order,
          payment_method: payment_method,
          amount: total_amount,
          status: 'pending',
          gateway_transaction_id: nil,
          gateway_response: nil,
          metadata: payment_data
        )
      end

      def process_with_gateway(payment, payment_data)
        case payment.payment_method.gateway_type
        when 'stripe'
          process_stripe_payment(payment, payment_data)
        when 'paypal'
          process_paypal_payment(payment, payment_data)
        when 'square'
          process_square_payment(payment, payment_data)
        else
          { success: false, error: "Unsupported gateway type: #{payment.payment_method.gateway_type}" }
        end
      end

      def process_refund_with_gateway(payment, refund_amount, reason)
        case payment.payment_method.gateway_type
        when 'stripe'
          process_stripe_refund(payment, refund_amount, reason)
        when 'paypal'
          process_paypal_refund(payment, refund_amount, reason)
        when 'square'
          process_square_refund(payment, refund_amount, reason)
        else
          { success: false, error: "Unsupported gateway type: #{payment.payment_method.gateway_type}" }
        end
      end

      def update_payment_status(payment, result)
        if result[:success]
          payment.update!(
            status: 'completed',
            gateway_transaction_id: result[:transaction_id],
            gateway_response: result[:gateway_response],
            processed_at: Time.current
          )
        else
          payment.update!(
            status: 'failed',
            gateway_response: result[:gateway_response],
            failure_reason: result[:error]
          )
        end
      end

      def update_refund_status(payment, result, refund_amount, reason)
        if result[:success]
          payment.update!(
            status: 'refunded',
            refund_amount: refund_amount,
            refund_reason: reason,
            refunded_at: Time.current
          )
        else
          payment.update!(
            failure_reason: result[:error]
          )
        end
      end

      # Gateway-specific payment processing methods
      def process_stripe_payment(payment, payment_data)
        # Mock Stripe payment processing
        {
          success: true,
          transaction_id: "stripe_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'succeeded' }
        }
      end

      def process_paypal_payment(payment, payment_data)
        # Mock PayPal payment processing
        {
          success: true,
          transaction_id: "paypal_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'completed' }
        }
      end

      def process_square_payment(payment, payment_data)
        # Mock Square payment processing
        {
          success: true,
          transaction_id: "square_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'approved' }
        }
      end

      def process_stripe_refund(payment, refund_amount, reason)
        # Mock Stripe refund processing
        {
          success: true,
          transaction_id: "stripe_refund_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'succeeded' }
        }
      end

      def process_paypal_refund(payment, refund_amount, reason)
        # Mock PayPal refund processing
        {
          success: true,
          transaction_id: "paypal_refund_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'completed' }
        }
      end

      def process_square_refund(payment, refund_amount, reason)
        # Mock Square refund processing
        {
          success: true,
          transaction_id: "square_refund_#{SecureRandom.hex(8)}",
          gateway_response: { status: 'approved' }
        }
      end
    end
  end
end
