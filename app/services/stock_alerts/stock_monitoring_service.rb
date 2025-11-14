# frozen_string_literal: true

module StockAlerts
  class StockMonitoringService
    class << self
      # Monitor all products for stock alerts
      # @return [Hash] Summary of monitoring results
      delegate :monitor_all_products, to: :StockMonitoringCoreService

      # Monitor specific products for stock alerts
      # @param product_ids [Array<Integer>] Array of product IDs to monitor
      # @return [Hash] Summary of monitoring results
      delegate :monitor_products, to: :StockMonitoringCoreService

      # Monitor products by category
      # @param category_ids [Array<Integer>] Array of category IDs
      # @return [Hash] Summary of monitoring results
      delegate :monitor_products_by_category, to: :StockMonitoringCoreService

      # @return [Hash] Alert summary data
      delegate :alert_summary, to: :StockMonitoringAnalyticsService

      # @return [Array<StockAlert>] Critical stock alerts
      delegate :critical_alerts, to: :StockMonitoringAnalyticsService

      # @return [Array<StockAlert>] Low stock alerts
      delegate :low_stock_alerts, to: :StockMonitoringAnalyticsService

      # @return [Array<StockAlert>] Alerts that haven't been notified
      delegate :alerts_pending_notification, to: :StockMonitoringAnalyticsService

      # @param severity [String] Severity level
      # @return [Array<StockAlert>] Alerts of specified severity
      delegate :alerts_by_severity, to: :StockMonitoringAnalyticsService

      # Mark notifications as sent
      # @param alert_ids [Array<Integer>] Alert IDs to mark
      # @return [Integer] Number of alerts marked
      delegate :mark_notifications_sent, to: :StockMonitoringAnalyticsService

      # Calculate recommended quantity for a product
      # @param product [Product] Product to calculate for
      # @return [Integer] Recommended quantity
      delegate :calculate_recommended_quantity, to: :StockMonitoringRecommendationService

      # @param limit [Integer] Maximum number of recommendations
      # @return [Array<Hash>] Reorder recommendations
      def get_reorder_recommendations(limit = 50)
        StockMonitoringRecommendationService.get_reorder_recommendations(limit)
      end

      # @param product [Product] Product to analyze
      # @return [Hash] Stock level recommendations
      delegate :get_stock_level_recommendations, to: :StockMonitoringRecommendationService
    end
  end
end
