# frozen_string_literal: true

module Payments
  class PaymentMethodService
    class << self
      # Get all active payment methods
      # @return [Array<PaymentMethod>] Active payment methods
      def get_active_payment_methods
        PaymentMethod.active.includes(:payments)
      end

      # Get payment methods by gateway type
      # @param gateway_type [String] The gateway type to filter by
      # @return [Array<PaymentMethod>] Payment methods for the gateway
      def get_payment_methods_by_gateway(gateway_type)
        PaymentMethod.active.by_gateway_type(gateway_type)
      end

      # Create a new payment method
      # @param params [Hash] Payment method parameters
      # @return [Hash] Result with success status and payment method
      def create_payment_method(params)
        payment_method = PaymentMethod.new(params)

        if payment_method.save
          {
            success: true,
            payment_method: payment_method,
            message: 'Payment method created successfully'
          }
        else
          {
            success: false,
            errors: payment_method.errors.full_messages,
            message: 'Failed to create payment method'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method creation error: #{e.message}"
        {
          success: false,
          error: 'Payment method creation failed',
          details: e.message
        }
      end

      # Update a payment method
      # @param payment_method [PaymentMethod] The payment method to update
      # @param params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_payment_method(payment_method, params)
        if payment_method.update(params)
          {
            success: true,
            payment_method: payment_method,
            message: 'Payment method updated successfully'
          }
        else
          {
            success: false,
            errors: payment_method.errors.full_messages,
            message: 'Failed to update payment method'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method update error: #{e.message}"
        {
          success: false,
          error: 'Payment method update failed',
          details: e.message
        }
      end

      # Deactivate a payment method
      # @param payment_method [PaymentMethod] The payment method to deactivate
      # @return [Hash] Result with success status
      def deactivate_payment_method(payment_method)
        if payment_method.update(is_active: false)
          {
            success: true,
            message: 'Payment method deactivated successfully'
          }
        else
          {
            success: false,
            errors: payment_method.errors.full_messages,
            message: 'Failed to deactivate payment method'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method deactivation error: #{e.message}"
        {
          success: false,
          error: 'Payment method deactivation failed',
          details: e.message
        }
      end

      # Calculate processing fees for an amount
      # @param amount [Decimal] The amount to calculate fees for
      # @param payment_method [PaymentMethod] The payment method to use
      # @return [Hash] Fee calculation result
      def calculate_processing_fees(amount, payment_method)
        return { success: false, error: 'Invalid amount' } if amount.blank? || amount <= 0
        return { success: false, error: 'Payment method not found' } unless payment_method

        processing_fee = payment_method.calculate_processing_fee(amount)
        total_amount = payment_method.total_amount_with_fees(amount)

        {
          success: true,
          original_amount: amount,
          processing_fee: processing_fee,
          total_amount: total_amount,
          fee_breakdown: {
            percentage_fee: (amount * payment_method.processing_fee_percentage / 100).round(2),
            fixed_fee: payment_method.processing_fee_fixed
          }
        }
      rescue StandardError => e
        Rails.logger.error "Fee calculation error: #{e.message}"
        {
          success: false,
          error: 'Fee calculation failed',
          details: e.message
        }
      end

      # Get payment method statistics
      # @param payment_method [PaymentMethod] The payment method to get stats for
      # @param period [String] Time period (day, week, month, year)
      # @return [Hash] Statistics data
      def get_payment_method_stats(payment_method, period = 'month')
        return { success: false, error: 'Payment method not found' } unless payment_method

        start_date = case period
                     when 'day'
                       1.day.ago
                     when 'week'
                       1.week.ago
                     when 'month'
                       1.month.ago
                     when 'year'
                       1.year.ago
                     else
                       1.month.ago
                     end

        payments = payment_method.payments.where(created_at: start_date..)

        {
          success: true,
          period: period,
          start_date: start_date,
          end_date: Time.current,
          stats: {
            total_payments: payments.count,
            successful_payments: payments.successful.count,
            failed_payments: payments.failed.count,
            total_amount: payments.successful.sum(:amount),
            total_fees: payments.successful.sum { |p| p.processing_fee },
            average_amount: payments.successful.average(:amount)&.round(2) || 0,
            success_rate: payments.count > 0 ? (payments.successful.count.to_f / payments.count * 100).round(2) : 0
          }
        }
      rescue StandardError => e
        Rails.logger.error "Payment method stats error: #{e.message}"
        {
          success: false,
          error: 'Failed to get payment method statistics',
          details: e.message
        }
      end

      # Validate payment method configuration
      # @param payment_method [PaymentMethod] The payment method to validate
      # @return [Hash] Validation result
      def validate_payment_method_config(payment_method)
        return { success: false, error: 'Payment method not found' } unless payment_method

        errors = []

        # Check if gateway is configured
        errors << 'Gateway configuration is missing' unless payment_method.gateway_configured?

        # Validate gateway-specific configuration
        case payment_method.gateway_type
        when 'stripe'
          errors.concat(validate_stripe_config(payment_method))
        when 'paypal'
          errors.concat(validate_paypal_config(payment_method))
        when 'bank_transfer'
          errors.concat(validate_bank_transfer_config(payment_method))
        end

        {
          success: errors.empty?,
          errors: errors,
          message: errors.empty? ? 'Payment method configuration is valid' : 'Configuration has errors'
        }
      rescue StandardError => e
        Rails.logger.error "Payment method validation error: #{e.message}"
        {
          success: false,
          error: 'Payment method validation failed',
          details: e.message
        }
      end

      private

      def validate_stripe_config(payment_method)
        errors = []
        config = payment_method.gateway_config

        errors << 'Stripe publishable key is required' unless config&.dig('publishable_key').present?
        errors << 'Stripe secret key is required' unless config&.dig('secret_key').present?

        errors
      end

      def validate_paypal_config(payment_method)
        errors = []
        config = payment_method.gateway_config

        errors << 'PayPal client ID is required' unless config&.dig('client_id').present?
        errors << 'PayPal client secret is required' unless config&.dig('client_secret').present?
        errors << 'PayPal environment is required' unless config&.dig('environment').present?

        errors
      end

      def validate_bank_transfer_config(payment_method)
        errors = []
        config = payment_method.gateway_config

        errors << 'Bank account details are required' unless config&.dig('bank_account').present?
        errors << 'Bank routing number is required' unless config&.dig('routing_number').present?

        errors
      end
    end
  end
end
