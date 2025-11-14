# frozen_string_literal: true

module StockAlerts
  class StockAlertStatisticsService
    class << self
      # @param period [String] Time period for statistics
      # @return [Hash] Alert statistics
      def get_statistics(period = 'month')
        start_date = calculate_start_date(period)
        alerts = StockAlert.where(created_at: start_date..)

        {
          success: true,
          period: period,
          total_alerts: alerts.count,
          active_alerts: alerts.active.count,
          resolved_alerts: alerts.resolved.count,
          alerts_by_type: alerts_by_type(alerts),
          alerts_by_severity: alerts_by_severity(alerts),
          recent_alerts: recent_alerts(alerts)
        }
      rescue StandardError => e
        Rails.logger.error "Stock alert statistics error: #{e.message}"
        {
          success: false,
          error: 'Failed to retrieve alert statistics',
          details: e.message
        }
      end

      private

      def calculate_start_date(period)
        case period
        when 'day'
          1.day.ago
        when 'week'
          1.week.ago
        when 'year'
          1.year.ago
        else
          1.month.ago # Default to month
        end
      end

      def alerts_by_type(alerts)
        alerts.group(:alert_type).count
      end

      def alerts_by_severity(alerts)
        severity_map = {
          'out_of_stock' => 'critical',
          'critical_stock' => 'high',
          'low_stock' => 'medium',
          'reorder_point' => 'low'
        }

        alerts.group(:alert_type).count.transform_keys { |type| severity_map[type] || 'unknown' }
      end

      def recent_alerts(alerts)
        alerts.limit(10).map do |alert|
          {
            id: alert.id,
            product_name: alert.product.name,
            alert_type: alert.alert_type,
            triggered_at: alert.triggered_at
          }
        end
      end
    end
  end
end
