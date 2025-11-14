# frozen_string_literal: true

module StockAlerts
  class StockMonitoringAnalyticsService
    class << self
      # @return [Hash] Alert summary data
      def alert_summary
        {
          total_alerts: StockAlert.count,
          active_alerts: StockAlert.active.count,
          resolved_alerts: StockAlert.resolved.count,
          critical_alerts: critical_alerts_count,
          low_stock_alerts: low_stock_alerts_count,
          alerts_pending_notification: alerts_pending_notification_count
        }
      end

      # @return [Array<StockAlert>] Critical stock alerts
      def critical_alerts
        StockAlert.active.where(alert_type: %w[out_of_stock critical_stock])
                  .includes(:product)
                  .order(triggered_at: :desc)
      end

      # @return [Array<StockAlert>] Low stock alerts
      def low_stock_alerts
        StockAlert.active.where(alert_type: %w[low_stock reorder_point])
                  .includes(:product)
                  .order(triggered_at: :desc)
      end

      # @return [Array<StockAlert>] Alerts that haven't been notified
      def alerts_pending_notification
        StockAlert.active.where(notification_sent: false)
                  .includes(:product)
                  .order(triggered_at: :desc)
      end

      # @param severity [String] Severity level
      # @return [Array<StockAlert>] Alerts of specified severity
      def alerts_by_severity(severity)
        alert_types = severity_alert_types(severity)
        return [] if alert_types.empty?

        StockAlert.active.where(alert_type: alert_types)
                  .includes(:product)
                  .order(triggered_at: :desc)
      end

      # Mark notifications as sent
      # @param alert_ids [Array<Integer>] Alert IDs to mark
      # @return [Integer] Number of alerts marked
      def mark_notifications_sent(alert_ids)
        marked_count = 0
        StockAlert.where(id: alert_ids).find_each do |alert|
          alert.update!(notification_sent: true)
          marked_count += 1
        end
        marked_count
      end

      private

      def critical_alerts_count
        StockAlert.active.where(alert_type: %w[out_of_stock critical_stock]).count
      end

      def low_stock_alerts_count
        StockAlert.active.where(alert_type: %w[low_stock reorder_point]).count
      end

      def alerts_pending_notification_count
        StockAlert.active.where(notification_sent: false).count
      end

      def severity_alert_types(severity)
        case severity
        when 'critical'
          %w[out_of_stock]
        when 'high'
          %w[critical_stock]
        when 'medium'
          %w[low_stock]
        when 'low'
          %w[reorder_point]
        else
          []
        end
      end
    end
  end
end
