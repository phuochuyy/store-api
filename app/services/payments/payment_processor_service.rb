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
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'Payment method not found' } unless payment_method
        return { success: false, error: 'Order cannot be paid' } unless order.can_be_paid?
        return { success: false, error: 'Payment method is not active' } unless payment_method.is_active?

        # Calculate total amount including processing fees
        total_amount = payment_method.total_amount_with_fees(order.total_amount)

        # Create payment record
        payment = create_payment_record(order, payment_method, total_amount, payment_data)

        # Process payment based on gateway type
        result = process_with_gateway(payment, payment_data)

        # Update payment status based on result
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

        # Process refund with gateway
        result = process_refund_with_gateway(payment, refund_amount, reason)

        # Update payment status based on result
        update_refund_status(payment, result, refund_amount)

        result
      rescue StandardError => e
        Rails.logger.error "Refund processing error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Refund processing failed', details: e.message }
      end

      private

      def create_payment_record(order, payment_method, amount, payment_data)
        Payment.create!(
          order: order,
          payment_method: payment_method,
          amount: amount,
          currency: 'USD',
          metadata: payment_data.except(:card_number, :cvv, :expiry_month, :expiry_year)
        )
      end

      def process_with_gateway(payment, payment_data)
        case payment.payment_method.gateway_type
        when 'stripe'
          process_stripe_payment(payment, payment_data)
        when 'paypal'
          process_paypal_payment(payment, payment_data)
        when 'bank_transfer'
          process_bank_transfer_payment(payment, payment_data)
        when 'cash_on_delivery'
          process_cash_on_delivery_payment(payment, payment_data)
        when 'wallet'
          process_wallet_payment(payment, payment_data)
        else
          { success: false, error: 'Unsupported payment gateway' }
        end
      end

      def process_stripe_payment(payment, payment_data)
        # Mock Stripe payment processing
        # In real implementation, integrate with Stripe API
        Rails.logger.info "Processing Stripe payment for #{payment.amount}"

        # Simulate processing delay
        sleep(0.1)

        # Mock success response
        {
          success: true,
          transaction_id: "stripe_#{SecureRandom.hex(8)}",
          gateway_response: {
            id: "pi_#{SecureRandom.hex(8)}",
            status: 'succeeded',
            amount: (payment.amount * 100).to_i, # Stripe uses cents
            currency: payment.currency.downcase
          }.to_json
        }
      end

      def process_paypal_payment(payment, payment_data)
        # Mock PayPal payment processing
        Rails.logger.info "Processing PayPal payment for #{payment.amount}"

        sleep(0.1)

        {
          success: true,
          transaction_id: "paypal_#{SecureRandom.hex(8)}",
          gateway_response: {
            id: "PAY-#{SecureRandom.hex(8)}",
            state: 'approved',
            amount: payment.amount,
            currency: payment.currency
          }.to_json
        }
      end

      def process_bank_transfer_payment(payment, payment_data)
        # Bank transfer is always pending until manually confirmed
        Rails.logger.info "Creating bank transfer payment for #{payment.amount}"

        {
          success: true,
          transaction_id: "bank_#{SecureRandom.hex(8)}",
          gateway_response: {
            status: 'pending',
            instructions: 'Please transfer the amount to our bank account',
            reference: payment.transaction_id
          }.to_json
        }
      end

      def process_cash_on_delivery_payment(payment, payment_data)
        # Cash on delivery is always pending
        Rails.logger.info "Creating cash on delivery payment for #{payment.amount}"

        {
          success: true,
          transaction_id: "cod_#{SecureRandom.hex(8)}",
          gateway_response: {
            status: 'pending',
            instructions: 'Payment will be collected on delivery'
          }.to_json
        }
      end

      def process_wallet_payment(payment, payment_data)
        # Mock wallet payment processing
        Rails.logger.info "Processing wallet payment for #{payment.amount}"

        sleep(0.1)

        {
          success: true,
          transaction_id: "wallet_#{SecureRandom.hex(8)}",
          gateway_response: {
            id: "wallet_#{SecureRandom.hex(8)}",
            status: 'completed',
            amount: payment.amount,
            currency: payment.currency
          }.to_json
        }
      end

      def process_refund_with_gateway(payment, amount, reason)
        case payment.payment_method.gateway_type
        when 'stripe'
          process_stripe_refund(payment, amount, reason)
        when 'paypal'
          process_paypal_refund(payment, amount, reason)
        else
          { success: false, error: 'Refunds not supported for this payment method' }
        end
      end

      def process_stripe_refund(payment, amount, reason)
        Rails.logger.info "Processing Stripe refund for #{amount}"

        sleep(0.1)

        {
          success: true,
          transaction_id: "re_#{SecureRandom.hex(8)}",
          gateway_response: {
            id: "re_#{SecureRandom.hex(8)}",
            status: 'succeeded',
            amount: (amount * 100).to_i,
            reason: reason
          }.to_json
        }
      end

      def process_paypal_refund(payment, amount, reason)
        Rails.logger.info "Processing PayPal refund for #{amount}"

        sleep(0.1)

        {
          success: true,
          transaction_id: "refund_#{SecureRandom.hex(8)}",
          gateway_response: {
            id: "refund_#{SecureRandom.hex(8)}",
            state: 'completed',
            amount: amount,
            reason: reason
          }.to_json
        }
      end

      def update_payment_status(payment, result)
        if result[:success]
          payment.mark_as_completed!(
            transaction_id: result[:transaction_id],
            gateway_response: result[:gateway_response]
          )
        else
          payment.mark_as_failed!(
            reason: result[:error],
            gateway_response: result[:gateway_response]
          )
        end
      end

      def update_refund_status(payment, result, refund_amount)
        if result[:success]
          if refund_amount == payment.amount
            payment.mark_as_refunded!(gateway_response: result[:gateway_response])
          else
            payment.mark_as_partially_refunded!(gateway_response: result[:gateway_response])
          end
        else
          Rails.logger.error "Refund failed: #{result[:error]}"
        end
      end
    end
  end
end
