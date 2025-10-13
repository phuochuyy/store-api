# frozen_string_literal: true

module Payments
  class PaymentMethodService
    class << self
      # Get all active payment methods
      # @return [Array<PaymentMethod>] Active payment methods
      def active_payment_methods
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
      delegate :create_payment_method, to: :PaymentMethodCreationService

      # Update a payment method
      # @param payment_method [PaymentMethod] The payment method to update
      # @param params [Hash] Update parameters
      # @return [Hash] Result with success status
      delegate :update_payment_method, to: :PaymentMethodCreationService

      # Delete a payment method
      # @param payment_method [PaymentMethod] The payment method to delete
      # @return [Hash] Result with success status
      delegate :delete_payment_method, to: :PaymentMethodCreationService

      # Calculate processing fees for a payment method
      # @param amount [Decimal] Payment amount
      # @param payment_method [PaymentMethod] Payment method to calculate fees for
      # @return [Hash] Fee calculation result
      def calculate_processing_fees(amount, payment_method)
        return { success: false, error: 'Amount is required' } if amount.blank?
        return { success: false, error: 'Payment method is required' } unless payment_method

        fee_calculation = perform_fee_calculation(amount, payment_method)
        build_fee_response(amount, fee_calculation)
      rescue StandardError => e
        Rails.logger.error "Fee calculation error: #{e.message}"
        {
          success: false,
          error: 'Fee calculation failed',
          details: e.message
        }
      end

      # Get payment method statistics
      # @param payment_method [PaymentMethod] Payment method to analyze
      # @param period [String] Time period for statistics
      # @return [Hash] Payment method statistics
      def get_payment_method_stats(payment_method, period = 'month')
        PaymentMethodAnalyticsService.get_payment_method_stats(payment_method, period)
      end

      # Get payment method performance comparison
      # @param period [String] Time period for comparison
      # @return [Hash] Performance comparison data
      def get_payment_method_performance(period = 'month')
        PaymentMethodAnalyticsService.get_payment_method_performance(period)
      end

      # Get payment method trends
      # @param payment_method [PaymentMethod] Payment method to analyze
      # @param days [Integer] Number of days to analyze
      # @return [Hash] Trend data
      def get_payment_method_trends(payment_method, days = 30)
        PaymentMethodAnalyticsService.get_payment_method_trends(payment_method, days)
      end

      # Validate payment method configuration
      # @param payment_method [PaymentMethod] Payment method to validate
      # @return [Hash] Validation result
      delegate :validate_payment_method_config, to: :PaymentMethodValidationService

      # Test payment method connectivity
      # @param payment_method [PaymentMethod] Payment method to test
      # @return [Hash] Test result
      delegate :test_payment_method_connectivity, to: :PaymentMethodValidationService

      private

      def perform_fee_calculation(amount, payment_method)
        percentage_fee = calculate_percentage_fee(amount, payment_method)
        fixed_fee = payment_method.fee_fixed_amount || 0
        total_fee = percentage_fee + fixed_fee

        {
          amount: amount,
          percentage_fee: percentage_fee,
          fixed_fee: fixed_fee,
          total_fee: total_fee,
          net_amount: amount - total_fee
        }
      end

      def calculate_percentage_fee(amount, payment_method)
        return 0 unless payment_method.fee_percentage

        (amount * payment_method.fee_percentage / 100).round(2)
      end

      def build_fee_response(amount, fee_calculation)
        {
          success: true,
          original_amount: amount,
          processing_fee: fee_calculation[:total_fee],
          net_amount: fee_calculation[:net_amount],
          fee_breakdown: {
            percentage_fee: fee_calculation[:percentage_fee],
            fixed_fee: fee_calculation[:fixed_fee]
          }
        }
      end
    end
  end
end
