# frozen_string_literal: true

module StockAlerts
  class StockAlertQueryService
    class << self
      # Get stock alerts with filters and pagination
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
        StockAlert.includes(:product, :user)
                  .order(created_at: :desc)
      end

      def apply_filters(alerts, filters)
        alerts = alerts.where(status: filters[:status]) if filters[:status].present?
        alerts = alerts.where(alert_type: filters[:alert_type]) if filters[:alert_type].present?
        alerts = alerts.where(product_id: filters[:product_id]) if filters[:product_id].present?

        if filters[:start_date].present? && filters[:end_date].present?
          start_date = Date.parse(filters[:start_date])
          end_date = Date.parse(filters[:end_date])
          alerts = alerts.where(triggered_at: start_date.beginning_of_day..end_date.end_of_day)
        end

        if filters[:severity].present?
          severity_map = {
            'critical' => %w[out_of_stock],
            'high' => %w[critical_stock],
            'medium' => %w[low_stock],
            'low' => %w[reorder_point]
          }
          alert_types = severity_map[filters[:severity]]
          alerts = alerts.where(alert_type: alert_types) if alert_types
        end

        alerts
      end

      def apply_pagination(alerts, page, per_page)
        alerts.page(page).per(per_page)
      end

      def build_pagination_info(alerts, page, per_page)
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
