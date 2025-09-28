# frozen_string_literal: true

module StockAlerts
  class StockAlertService
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

        # Check for existing active alert of the same type
        existing_alert = StockAlert.active_alerts.find_by(product: product, alert_type: alert_type)
        if existing_alert
          return {
            success: false,
            error: 'Active alert of this type already exists',
            existing_alert: existing_alert
          }
        end

        # Set default threshold if not provided
        threshold ||= default_threshold_for_type(alert_type)

        alert = StockAlert.create!(
          product: product,
          alert_type: alert_type,
          threshold: threshold,
          current_stock: product.stock_quantity,
          triggered_at: Time.current,
          message: custom_message || StockAlert.generate_alert_message(product, alert_type, threshold,
                                                                       product.stock_quantity)
        )

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

      # Update an existing stock alert
      # @param alert [StockAlert] The alert to update
      # @param params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_alert(alert, params)
        return { success: false, error: 'Alert not found' } unless alert

        if alert.update(params)
          {
            success: true,
            alert: alert,
            message: 'Stock alert updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update stock alert',
            details: alert.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Stock alert update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update stock alert',
          details: e.message
        }
      end

      # Resolve a stock alert
      # @param alert [StockAlert] The alert to resolve
      # @param resolved_by [String] Who resolved the alert
      # @param resolution_notes [String] Resolution notes
      # @return [Hash] Result with success status
      def resolve_alert(alert, resolved_by: nil, resolution_notes: nil)
        return { success: false, error: 'Alert not found' } unless alert
        return { success: false, error: 'Alert is not active' } unless alert.active?

        alert.resolve!(resolved_by: resolved_by, resolution_notes: resolution_notes)

        {
          success: true,
          alert: alert,
          message: 'Stock alert resolved successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Stock alert resolution error: #{e.message}"
        {
          success: false,
          error: 'Failed to resolve stock alert',
          details: e.message
        }
      end

      # Dismiss a stock alert
      # @param alert [StockAlert] The alert to dismiss
      # @param dismissed_by [String] Who dismissed the alert
      # @param dismissal_reason [String] Dismissal reason
      # @return [Hash] Result with success status
      def dismiss_alert(alert, dismissed_by: nil, dismissal_reason: nil)
        return { success: false, error: 'Alert not found' } unless alert
        return { success: false, error: 'Alert is not active' } unless alert.active?

        alert.dismiss!(dismissed_by: dismissed_by, dismissal_reason: dismissal_reason)

        {
          success: true,
          alert: alert,
          message: 'Stock alert dismissed successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Stock alert dismissal error: #{e.message}"
        {
          success: false,
          error: 'Failed to dismiss stock alert',
          details: e.message
        }
      end

      # Get alerts with filtering and pagination
      # @param filters [Hash] Filter parameters
      # @param page [Integer] Page number for pagination
      # @param per_page [Integer] Items per page
      # @return [Hash] Filtered alerts with pagination info
      def get_alerts(filters: {}, page: 1, per_page: 20)
        alerts = StockAlert.includes(:product)

        # Apply filters
        alerts = alerts.where(status: filters[:status]) if filters[:status].present?
        alerts = alerts.where(alert_type: filters[:alert_type]) if filters[:alert_type].present?
        alerts = alerts.where(product_id: filters[:product_id]) if filters[:product_id].present?
        alerts = alerts.where(notification_sent: filters[:notification_sent]) if filters[:notification_sent].present?

        # Date range filters
        if filters[:start_date].present? && filters[:end_date].present?
          start_date = Date.parse(filters[:start_date])
          end_date = Date.parse(filters[:end_date])
          alerts = alerts.where(triggered_at: start_date.beginning_of_day..end_date.end_of_day)
        end

        # Severity filter
        if filters[:severity].present?
          alert_types = case filters[:severity]
                        when 'critical'
                          %w[out_of_stock]
                        when 'high'
                          %w[critical_stock]
                        when 'medium'
                          %w[low_stock]
                        when 'low'
                          %w[reorder_point]
                        end
          alerts = alerts.where(alert_type: alert_types) if alert_types
        end

        # Order by severity and recency
        alerts = alerts.order(
          Arel.sql("CASE alert_type
                   WHEN 'out_of_stock' THEN 1
                   WHEN 'critical_stock' THEN 2
                   WHEN 'low_stock' THEN 3
                   WHEN 'reorder_point' THEN 4
                   ELSE 5 END"),
          triggered_at: :desc
        )

        # Pagination
        total_count = alerts.count
        alerts = alerts.page(page).per(per_page)

        {
          success: true,
          alerts: alerts.map { |alert| alert_serializer(alert) },
          pagination: {
            current_page: alerts.current_page,
            total_pages: alerts.total_pages,
            total_count: total_count,
            per_page: per_page
          }
        }
      end

      # Get alert statistics
      # @param period [String] Time period for statistics
      # @return [Hash] Alert statistics
      def get_alert_statistics(period = 'month')
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

        alerts = StockAlert.where(created_at: start_date..)

        {
          success: true,
          period: period,
          start_date: start_date,
          end_date: Time.current,
          statistics: {
            total_alerts: alerts.count,
            active_alerts: alerts.active_alerts.count,
            resolved_alerts: alerts.resolved_alerts.count,
            dismissed_alerts: alerts.dismissed.count,
            alerts_by_type: alerts.group(:alert_type).count,
            alerts_by_severity: get_severity_breakdown(alerts),
            average_resolution_time: calculate_average_resolution_time(alerts),
            products_with_alerts: alerts.joins(:product).distinct.count(:product_id),
            notification_sent_rate: calculate_notification_rate(alerts)
          }
        }
      end

      # Bulk operations
      # @param alert_ids [Array<Integer>] Alert IDs for bulk operations
      # @param action [String] Action to perform (resolve, dismiss, mark_notified)
      # @param params [Hash] Additional parameters
      # @return [Hash] Result of bulk operation
      def bulk_operation(alert_ids, action, params = {})
        return { success: false, error: 'No alerts selected' } if alert_ids.blank?

        alerts = StockAlert.where(id: alert_ids)
        return { success: false, error: 'No valid alerts found' } if alerts.empty?

        case action
        when 'resolve'
          resolved_count = StockAlerts::StockMonitoringService.resolve_alerts(
            alert_ids,
            resolved_by: params[:resolved_by],
            resolution_notes: params[:resolution_notes]
          )
          {
            success: true,
            message: "#{resolved_count} alerts resolved successfully",
            count: resolved_count
          }
        when 'dismiss'
          dismissed_count = StockAlerts::StockMonitoringService.dismiss_alerts(
            alert_ids,
            dismissed_by: params[:dismissed_by],
            dismissal_reason: params[:dismissal_reason]
          )
          {
            success: true,
            message: "#{dismissed_count} alerts dismissed successfully",
            count: dismissed_count
          }
        when 'mark_notified'
          updated_count = StockAlerts::StockMonitoringService.mark_notifications_sent(alert_ids)
          {
            success: true,
            message: "#{updated_count} alerts marked as notification sent",
            count: updated_count
          }
        else
          { success: false, error: 'Invalid action' }
        end
      rescue StandardError => e
        Rails.logger.error "Bulk operation error: #{e.message}"
        {
          success: false,
          error: 'Bulk operation failed',
          details: e.message
        }
      end

      private

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
          0
        end
      end

      def alert_serializer(alert)
        {
          id: alert.id,
          product_id: alert.product_id,
          product_name: alert.product.name,
          product_sku: alert.product.id, # Using ID as SKU for now
          alert_type: alert.alert_type,
          threshold: alert.threshold,
          current_stock: alert.current_stock,
          status: alert.status,
          severity_level: alert.severity_level,
          severity_score: alert.severity_score,
          message: alert.message,
          triggered_at: alert.triggered_at,
          resolved_at: alert.resolved_at,
          notification_sent: alert.notification_sent,
          duration: alert.duration,
          active_duration: alert.active_duration,
          created_at: alert.created_at,
          updated_at: alert.updated_at
        }
      end

      def get_severity_breakdown(alerts)
        {
          critical: alerts.where(alert_type: 'out_of_stock').count,
          high: alerts.where(alert_type: 'critical_stock').count,
          medium: alerts.where(alert_type: 'low_stock').count,
          low: alerts.where(alert_type: 'reorder_point').count
        }
      end

      def calculate_average_resolution_time(alerts)
        resolved_alerts = alerts.resolved_alerts.where.not(resolved_at: nil)
        return 0 if resolved_alerts.empty?

        total_time = resolved_alerts.sum { |alert| alert.duration || 0 }
        (total_time / resolved_alerts.count / 1.hour).round(2) # in hours
      end

      def calculate_notification_rate(alerts)
        total_alerts = alerts.count
        return 0 if total_alerts.zero?

        notified_alerts = alerts.where(notification_sent: true).count
        (notified_alerts.to_f / total_alerts * 100).round(2)
      end
    end
  end
end
