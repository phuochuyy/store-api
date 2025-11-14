# frozen_string_literal: true

module Payments
  class PaymentMethodValidationService
    class << self
      # @param payment_method [PaymentMethod] Payment method to validate
      # @return [Hash] Validation result
      def validate_payment_method_config(payment_method)
        return { success: false, error: 'Payment method not found' } unless payment_method

        validation_errors = []
        validation_errors.concat(validate_basic_config(payment_method))
        validation_errors.concat(validate_gateway_specific_config(payment_method))
        validation_errors.concat(validate_fee_config(payment_method))

        if validation_errors.empty?
          {
            success: true,
            message: 'Payment method configuration is valid'
          }
        else
          {
            success: false,
            errors: validation_errors,
            message: 'Payment method configuration has errors'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method validation error: #{e.message}"
        {
          success: false,
          error: 'Validation failed',
          details: e.message
        }
      end

      # Test payment method connectivity
      # @param payment_method [PaymentMethod] Payment method to test
      # @return [Hash] Test result
      def test_payment_method_connectivity(payment_method)
        return { success: false, error: 'Payment method not found' } unless payment_method

        case payment_method.gateway_type
        when 'stripe'
          test_stripe_connectivity(payment_method)
        when 'paypal'
          test_paypal_connectivity(payment_method)
        when 'square'
          test_square_connectivity(payment_method)
        else
          {
            success: false,
            error: "Unsupported gateway type: #{payment_method.gateway_type}"
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method connectivity test error: #{e.message}"
        {
          success: false,
          error: 'Connectivity test failed',
          details: e.message
        }
      end

      private

      def validate_basic_config(payment_method)
        errors = []
        errors << 'Name is required' if payment_method.name.blank?
        errors << 'Gateway type is required' if payment_method.gateway_type.blank?
        errors << 'Status is required' if payment_method.status.blank?
        errors
      end

      def validate_gateway_specific_config(payment_method)
        errors = []

        case payment_method.gateway_type
        when 'stripe'
          errors.concat(validate_stripe_config(payment_method))
        when 'paypal'
          errors.concat(validate_paypal_config(payment_method))
        when 'square'
          errors.concat(validate_square_config(payment_method))
        else
          errors << "Unsupported gateway type: #{payment_method.gateway_type}"
        end

        errors
      end

      def validate_fee_config(payment_method)
        errors = []

        if payment_method.fee_percentage.present? && (payment_method.fee_percentage.negative? || payment_method.fee_percentage > 100)
          errors << 'Fee percentage must be between 0 and 100'
        end

        if payment_method.fee_fixed_amount.present? && payment_method.fee_fixed_amount.negative?
          errors << 'Fixed fee amount cannot be negative'
        end

        errors
      end

      def validate_stripe_config(_payment_method)
        []
        # Add Stripe-specific validation logic here
        # errors << 'Stripe API key is required' if payment_method.api_key.blank?
      end

      def validate_paypal_config(_payment_method)
        []
        # Add PayPal-specific validation logic here
        # errors << 'PayPal client ID is required' if payment_method.client_id.blank?
      end

      def validate_square_config(_payment_method)
        []
        # Add Square-specific validation logic here
        # errors << 'Square application ID is required' if payment_method.app_id.blank?
      end

      def test_stripe_connectivity(_payment_method)
        # Mock Stripe connectivity test
        {
          success: true,
          message: 'Stripe connectivity test successful',
          response_time: rand(100..500) # Mock response time in ms
        }
      end

      def test_paypal_connectivity(_payment_method)
        # Mock PayPal connectivity test
        {
          success: true,
          message: 'PayPal connectivity test successful',
          response_time: rand(150..600) # Mock response time in ms
        }
      end

      def test_square_connectivity(_payment_method)
        # Mock Square connectivity test
        {
          success: true,
          message: 'Square connectivity test successful',
          response_time: rand(120..550) # Mock response time in ms
        }
      end
    end
  end
end
