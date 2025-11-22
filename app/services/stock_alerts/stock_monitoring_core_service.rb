# frozen_string_literal: true

module StockAlerts
  class StockMonitoringCoreService
    class << self
      # Monitor all products for stock alerts
      # @return [Hash] Summary of monitoring results
      def monitor_all_products
        results = initialize_monitoring_results
        Product.find_each { |product| process_product_monitoring(product, results) }
        results
      end

      # Monitor specific products for stock alerts
      # @param product_ids [Array<Integer>] Array of product IDs to monitor
      # @return [Hash] Summary of monitoring results
      def monitor_products(product_ids)
        results = initialize_monitoring_results(product_ids.size)
        Product.where(id: product_ids).find_each { |product| process_product_monitoring(product, results) }
        results
      end

      # Monitor products by category
      # @param category_ids [Array<Integer>] Array of category IDs
      # @return [Hash] Summary of monitoring results
      def monitor_products_by_category(category_ids)
        results = initialize_monitoring_results
        products = Product.joins(:category).where(categories: { id: category_ids })
        products.find_each { |product| process_product_monitoring(product, results) }
        results
      end

      private

      def initialize_monitoring_results(total_products = nil)
        {
          total_products: total_products || 0,
          alerts_created: 0,
          alerts_resolved: 0,
          products_checked: 0,
          errors: []
        }
      end

      def process_product_monitoring(product, results)
        results[:products_checked] += 1
        results[:total_products] += 1

        alerts_created = StockAlert.check_and_create_alerts_for_product(product)
        results[:alerts_created] += alerts_created.size

        resolved_count = resolve_alerts_for_product(product)
        results[:alerts_resolved] += resolved_count
      rescue StandardError => e
        Rails.logger.error "Error monitoring product #{product.id}: #{e.message}"
        results[:errors] << "Product #{product.id}: #{e.message}"
      end

      def resolve_alerts_for_product(product)
        resolved_count = 0
        active_alerts = StockAlert.active_alerts.where(product: product)

        active_alerts.each do |alert|
          if should_resolve_alert?(alert, product)
            alert.update!(status: 'resolved', resolved_at: Time.current)
            resolved_count += 1
          end
        end

        resolved_count
      end

      def should_resolve_alert?(alert, product)
        case alert.alert_type
        when 'out_of_stock'
          product.stock_quantity.positive?
        when 'critical_stock', 'low_stock', 'reorder_point'
          product.stock_quantity > alert.threshold
        else
          false
        end
      end
    end
  end
end
