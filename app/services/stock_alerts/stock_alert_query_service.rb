# frozen_string_literal: true

module StockAlerts
  class StockAlertQueryService
    class << self
      # @param filters [Hash] Filter parameters
      # @param page [Integer] Page number
      # @param per_page [Integer] Items per page
      # @return [Hash] Result with alerts and pagination info
      def get_alerts(filters: {}, page: 1, per_page: 20)
        alerts = build_base_query
        alerts = apply_filters(alerts, filters)
        alerts = apply_pagination(alerts, page, per_page)

        {
          success: true,
          alerts: alerts.map { |alert| alert_serializer(alert) },
          pagination: build_pagination_info(alerts, page, per_page)
        }
      rescue StandardError => e
        Rails.logger.error "Stock alert query error: #{e.message}"
        {
          success: false,
          error: 'Failed to retrieve stock alerts',
          details: e.message
        }
      end

      private

      def build_base_query
        StockAlert.includes(:product)
                  .order(created_at: :desc)
      end

      def apply_filters(alerts, filters)
        alerts = apply_status_filter(alerts, filters[:status])
        alerts = apply_alert_type_filter(alerts, filters[:alert_type])
        alerts = apply_product_filter(alerts, filters[:product_id])
        alerts = apply_date_range_filter(alerts, filters[:start_date], filters[:end_date])
        apply_severity_filter(alerts, filters[:severity])
      end

      def apply_status_filter(alerts, status)
        return alerts if status.blank?

        alerts.where(status: status)
      end

      def apply_alert_type_filter(alerts, alert_type)
        return alerts if alert_type.blank?

        alerts.where(alert_type: alert_type)
      end

      def apply_product_filter(alerts, product_id)
        return alerts if product_id.blank?

        alerts.where(product_id: product_id)
      end

      def apply_date_range_filter(alerts, start_date, end_date)
        return alerts unless start_date.present? && end_date.present?

        start = Date.parse(start_date)
        finish = Date.parse(end_date)
        alerts.where(triggered_at: start.beginning_of_day..finish.end_of_day)
      end

      def apply_severity_filter(alerts, severity)
        return alerts if severity.blank?

        severity_map = {
          'critical' => %w[out_of_stock],
          'high' => %w[critical_stock],
          'medium' => %w[low_stock],
          'low' => %w[reorder_point]
        }
        alert_types = severity_map[severity]
        return alerts unless alert_types

        alerts.where(alert_type: alert_types)
      end

      def apply_pagination(alerts, page, per_page)
        alerts.page(page).per(per_page)
      end

      def build_pagination_info(alerts, _page, per_page)
        {
          current_page: alerts.current_page,
          total_pages: alerts.total_pages,
          total_count: alerts.total_count,
          per_page: per_page
        }
      end

      def alert_serializer(alert)
        {
          id: alert.id,
          product_id: alert.product_id,
          product_name: alert.product.name,
          alert_type: alert.alert_type,
          threshold: alert.threshold,
          current_stock: alert.current_stock,
          status: alert.status,
          message: alert.message,
          triggered_at: alert.triggered_at,
          resolved_at: alert.resolved_at,
          created_at: alert.created_at
        }
      end
    end
  end
end
