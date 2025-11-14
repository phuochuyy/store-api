# frozen_string_literal: true

module Payments
  class PaymentMethodCreationService
    class << self
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

      # @param payment_method [PaymentMethod] The payment method to update
      # @param params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_payment_method(payment_method, params)
        return { success: false, error: 'Payment method not found' } unless payment_method

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

      # @param payment_method [PaymentMethod] The payment method to delete
      # @return [Hash] Result with success status
      def delete_payment_method(payment_method)
        return { success: false, error: 'Payment method not found' } unless payment_method

        if payment_method.destroy
          {
            success: true,
            message: 'Payment method deleted successfully'
          }
        else
          {
            success: false,
            errors: payment_method.errors.full_messages,
            message: 'Failed to delete payment method'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Payment method deletion error: #{e.message}"
        {
          success: false,
          error: 'Payment method deletion failed',
          details: e.message
        }
      end
    end
  end
end
