# frozen_string_literal: true

module StockAlerts
  class StockMonitoringService
    class << self
      # Monitor all products for stock alerts
      # @return [Hash] Summary of monitoring results
      def monitor_all_products
        results = {
          total_products: 0,
          alerts_created: 0,
          alerts_resolved: 0,
          products_checked: 0,
          errors: []
        }

        Product.find_each do |product|

          results[:products_checked] += 1
          results[:total_products] += 1

          # Check and create alerts for this product
          alerts_created = StockAlert.check_and_create_alerts_for_product(product)
          results[:alerts_created] += alerts_created.size

          # Resolve existing alerts if stock has improved
          resolved_count = resolve_alerts_for_product(product)
          results[:alerts_resolved] += resolved_count
        rescue StandardError => e
          Rails.logger.error "Error monitoring product #{product.id}: #{e.message}"
          results[:errors] << "Product #{product.id}: #{e.message}"

        end

        results
      end

      # Monitor specific products for stock alerts
      # @param product_ids [Array<Integer>] Array of product IDs to monitor
      # @return [Hash] Summary of monitoring results
      def monitor_products(product_ids)
        results = {
          total_products: product_ids.size,
          alerts_created: 0,
          alerts_resolved: 0,
          products_checked: 0,
          errors: []
        }

        Product.where(id: product_ids).find_each do |product|

          results[:products_checked] += 1

          # Check and create alerts for this product
          alerts_created = StockAlert.check_and_create_alerts_for_product(product)
          results[:alerts_created] += alerts_created.size

          # Resolve existing alerts if stock has improved
          resolved_count = resolve_alerts_for_product(product)
          results[:alerts_resolved] += resolved_count
        rescue StandardError => e
          Rails.logger.error "Error monitoring product #{product.id}: #{e.message}"
          results[:errors] << "Product #{product.id}: #{e.message}"

        end

        results
      end

      # Monitor products by category
      # @param category_id [Integer] Category ID to monitor
      # @return [Hash] Summary of monitoring results
      def monitor_products_by_category(category_id)
        category = Category.find_by(id: category_id)
        return { error: 'Category not found' } unless category

        product_ids = category.products.pluck(:id)
        monitor_products(product_ids)
      end

      # Monitor products by brand
      # @param brand_id [Integer] Brand ID to monitor
      # @return [Hash] Summary of monitoring results
      def monitor_products_by_brand(brand_id)
        brand = Brand.find_by(id: brand_id)
        return { error: 'Brand not found' } unless brand

        product_ids = brand.products.pluck(:id)
        monitor_products(product_ids)
      end

      # Get stock alert summary
      # @return [Hash] Summary of current stock alerts
      def get_alert_summary
        {
          total_alerts: StockAlert.count,
          active_alerts: StockAlert.active_alerts.count,
          resolved_alerts: StockAlert.resolved_alerts.count,
          dismissed_alerts: StockAlert.dismissed.count,
          alerts_by_type: StockAlert.group(:alert_type).count,
          alerts_by_severity: get_alerts_by_severity,
          products_with_alerts: StockAlert.active_alerts.joins(:product).distinct.count(:product_id),
          recent_alerts: StockAlert.recent.limit(10).pluck(:id, :alert_type, :product_id)
        }
      end

      # Get critical stock alerts (out of stock and critical stock)
      # @return [Array<StockAlert>] Critical stock alerts
      def get_critical_alerts
        StockAlert.active_alerts.where(alert_type: %w[out_of_stock critical_stock])
                  .includes(:product)
                  .recent
      end

      # Get low stock alerts
      # @return [Array<StockAlert>] Low stock alerts
      def get_low_stock_alerts
        StockAlert.active_alerts.where(alert_type: %w[low_stock reorder_point])
                  .includes(:product)
                  .recent
      end

      # Get alerts that need notification
      # @return [Array<StockAlert>] Alerts pending notification
      def get_alerts_pending_notification
        StockAlert.active_alerts.notification_pending
                  .includes(:product)
                  .recent
      end

      # Mark alerts as notification sent
      # @param alert_ids [Array<Integer>] Alert IDs to mark as sent
      # @return [Integer] Number of alerts marked
      def mark_notifications_sent(alert_ids)
        StockAlert.where(id: alert_ids).update_all(notification_sent: true)
      end

      # Resolve multiple alerts
      # @param alert_ids [Array<Integer>] Alert IDs to resolve
      # @param resolved_by [String] Who resolved the alerts
      # @param resolution_notes [String] Resolution notes
      # @return [Integer] Number of alerts resolved
      def resolve_alerts(alert_ids, resolved_by: nil, resolution_notes: nil)
        resolved_count = 0

        StockAlert.where(id: alert_ids).find_each do |alert|
          alert.resolve!(resolved_by: resolved_by, resolution_notes: resolution_notes)
          resolved_count += 1
        end

        resolved_count
      end

      # Dismiss multiple alerts
      # @param alert_ids [Array<Integer>] Alert IDs to dismiss
      # @param dismissed_by [String] Who dismissed the alerts
      # @param dismissal_reason [String] Dismissal reason
      # @return [Integer] Number of alerts dismissed
      def dismiss_alerts(alert_ids, dismissed_by: nil, dismissal_reason: nil)
        dismissed_count = 0

        StockAlert.where(id: alert_ids).find_each do |alert|
          alert.dismiss!(dismissed_by: dismissed_by, dismissal_reason: dismissal_reason)
          dismissed_count += 1
        end

        dismissed_count
      end

      # Get stock trends for a product
      # @param product [Product] Product to analyze
      # @param days [Integer] Number of days to analyze
      # @return [Hash] Stock trend data
      def get_stock_trends(product, days = 30)
        alerts = product.stock_alerts
                        .where(triggered_at: days.days.ago..)
                        .order(:triggered_at)

        {
          product_id: product.id,
          product_name: product.name,
          current_stock: product.stock_quantity,
          current_status: product.stock_status,
          alerts_in_period: alerts.count,
          alert_timeline: alerts.map do |alert|
            {
              date: alert.triggered_at.to_date,
              alert_type: alert.alert_type,
              stock_level: alert.current_stock,
              status: alert.status
            }
          end,
          stock_changes: calculate_stock_changes(alerts)
        }
      end

      # Get products that need restocking
      # @param threshold [Integer] Minimum stock threshold
      # @return [Array<Product>] Products needing restocking
      def get_products_needing_restock(threshold = 10)
        Product.where('stock_quantity <= ?', threshold)
               .includes(:brand, :category, :stock_alerts)
               .order(:stock_quantity)
      end

      # Generate restock recommendations
      # @return [Array<Hash>] Restock recommendations
      def generate_restock_recommendations
        recommendations = []

        Product.includes(:brand, :category, :stock_alerts).find_each do |product|
          next if product.stock_quantity > 20 # Skip products with sufficient stock

          recommendation = {
            product_id: product.id,
            product_name: product.name,
            brand: product.brand.name,
            category: product.category.name,
            current_stock: product.stock_quantity,
            recommended_quantity: calculate_recommended_quantity(product),
            urgency: calculate_urgency(product),
            reason: generate_recommendation_reason(product)
          }

          recommendations << recommendation
        end

        recommendations.sort_by { |r| r[:urgency] }.reverse
      end

      private

      def resolve_alerts_for_product(product)
        resolved_count = 0

        StockAlert.active_alerts.where(product: product).find_each do |alert|
          # Check if alert should be resolved based on current stock
          should_resolve = case alert.alert_type
                           when 'out_of_stock'
                             product.stock_quantity > 0
                           when 'critical_stock'
                             product.stock_quantity > 5
                           when 'low_stock'
                             product.stock_quantity > 10
                           when 'reorder_point'
                             product.stock_quantity > 20
                           else
                             false
                           end

          if should_resolve
            alert.resolve!
            resolved_count += 1
          end
        end

        resolved_count
      end

      def get_alerts_by_severity
        {
          critical: StockAlert.active_alerts.where(alert_type: 'out_of_stock').count,
          high: StockAlert.active_alerts.where(alert_type: 'critical_stock').count,
          medium: StockAlert.active_alerts.where(alert_type: 'low_stock').count,
          low: StockAlert.active_alerts.where(alert_type: 'reorder_point').count
        }
      end

      def calculate_stock_changes(alerts)
        changes = []
        previous_stock = nil

        alerts.each do |alert|
          if previous_stock
            change = alert.current_stock - previous_stock
            changes << {
              date: alert.triggered_at.to_date,
              change: change,
              from: previous_stock,
              to: alert.current_stock
            }
          end
          previous_stock = alert.current_stock
        end

        changes
      end

      def calculate_recommended_quantity(product)
        # Simple recommendation based on current stock and category
        base_quantity = case product.stock_status
                        when 'out_of_stock'
                          50
                        when 'critical'
                          30
                        when 'low'
                          20
                        when 'reorder_point'
                          15
                        else
                          10
                        end

        # Adjust based on category (electronics might need more stock)
        multiplier = case product.category.name.downcase
                     when /electronic/
                       1.5
                     when /clothing/
                       1.2
                     else
                       1.0
                     end

        (base_quantity * multiplier).round
      end

      def calculate_urgency(product)
        case product.stock_status
        when 'out_of_stock'
          100
        when 'critical'
          80
        when 'low'
          60
        when 'reorder_point'
          40
        else
          20
        end
      end

      def generate_recommendation_reason(product)
        case product.stock_status
        when 'out_of_stock'
          'Product is completely out of stock and needs immediate restocking'
        when 'critical'
          'Product has critical stock level and may go out of stock soon'
        when 'low'
          'Product has low stock level and should be restocked'
        when 'reorder_point'
          'Product has reached reorder point and should be restocked soon'
        else
          'Product stock is sufficient but could be optimized'
        end
      end
    end
  end
end
