# frozen_string_literal: true

module StockAlerts
  class StockAlertCreationService
    class << self
      # Create a stock alert for a product
      # @param product [Product] The product to create alert for
      # @param alert_type [String] Type of alert to create
      # @param threshold [Integer] Stock threshold for the alert
      # @param custom_message [String] Custom message for the alert
      # @return [Hash] Result with success status and alert information
      def create_alert(product:, alert_type:, threshold: nil, custom_message: nil)
        return { success: false, error: 'Product not found' } unless product
        return { success: false, error: 'Invalid alert type' } unless valid_alert_type?(alert_type)

        existing_alert = check_existing_alert(product, alert_type)
        return existing_alert if existing_alert

        alert = create_new_alert(product, alert_type, threshold, custom_message)

        {
          success: true,
          alert: alert,
          message: 'Stock alert created successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Stock alert creation error: #{e.message}"
        {
          success: false,
          error: 'Failed to create stock alert',
          details: e.message
        }
      end

      private

      def check_existing_alert(product, alert_type)
        existing_alert = StockAlert.active_alerts.find_by(product: product, alert_type: alert_type)
        return unless existing_alert

        {
          success: false,
          error: 'Active alert of this type already exists',
          existing_alert: existing_alert
        }
      end

      def create_new_alert(product, alert_type, threshold, custom_message)
        threshold ||= default_threshold_for_type(alert_type)

        StockAlert.create!(
          product: product,
          alert_type: alert_type,
          threshold: threshold,
          current_stock: product.stock_quantity,
          triggered_at: Time.current,
          message: custom_message || StockAlert.generate_alert_message(product, alert_type, threshold,
                                                                       product.stock_quantity)
        )
      end

      def valid_alert_type?(alert_type)
        StockAlert.alert_types.key?(alert_type)
      end

      def default_threshold_for_type(alert_type)
        case alert_type
        when 'out_of_stock'
          0
        when 'critical_stock'
          5
        when 'low_stock'
          10
        when 'reorder_point'
          20
        else
          10 # Default to low_stock threshold
        end
      end
    end
  end
end
