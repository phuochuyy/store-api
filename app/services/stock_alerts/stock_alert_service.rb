# frozen_string_literal: true

module StockAlerts
  class StockAlertService
    class << self
      # @param product [Product] The product to create alert for
      # @param alert_type [String] Type of alert to create
      # @param threshold [Integer] Stock threshold for the alert
      # @param custom_message [String] Custom message for the alert
      # @return [Hash] Result with success status and alert information
      def create_alert(product:, alert_type:, threshold: nil, custom_message: nil)
        StockAlertCreationService.create_alert(
          product: product,
          alert_type: alert_type,
          threshold: threshold,
          custom_message: custom_message
        )
      end

      # @param alert [StockAlert] Alert to update
      # @param params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_alert(alert, params)
        return { success: false, error: 'Alert not found' } unless alert

        update_result = perform_alert_update(alert, params)
        build_update_response(alert, update_result)
      rescue StandardError => e
        Rails.logger.error "Stock alert update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update stock alert',
          details: e.message
        }
      end

      private

      def perform_alert_update(alert, params)
        alert.update(params)
      end

      def build_update_response(alert, success)
        if success
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
      end

      # @param filters [Hash] Filter parameters
      # @param page [Integer] Page number
      # @param per_page [Integer] Items per page
      # @return [Hash] Result with alerts and pagination info
      def get_alerts(filters: {}, page: 1, per_page: 20)
        StockAlertQueryService.get_alerts(filters: filters, page: page, per_page: per_page)
      end

      # @param period [String] Time period for statistics
      # @return [Hash] Alert statistics
      def get_alert_statistics(period = 'month')
        StockAlertStatisticsService.get_statistics(period)
      end

      # Perform bulk operations on alerts
      # @param alert_ids [Array<Integer>] Alert IDs to operate on
      # @param action [String] Action to perform
      # @param params [Hash] Additional parameters
      # @return [Hash] Result with success status
      def bulk_operation(alert_ids, action, params = {})
        return { success: false, error: 'No alerts provided' } if alert_ids.blank?

        alerts = StockAlert.where(id: alert_ids)
        return { success: false, error: 'No valid alerts found' } if alerts.empty?

        case action
        when 'resolve'
          resolve_alerts(alerts, params)
        when 'dismiss'
          dismiss_alerts(alerts, params)
        when 'delete'
          delete_alerts(alerts)
        else
          { success: false, error: "Unknown action: #{action}" }
        end
      rescue StandardError => e
        Rails.logger.error "Bulk operation error: #{e.message}"
        {
          success: false,
          error: 'Failed to perform bulk operation',
          details: e.message
        }
      end

      def resolve_alerts(alerts, params)
        resolved_count = 0
        alerts.find_each do |alert|
          alert.update!(
            status: 'resolved',
            resolved_at: Time.current,
            resolution_notes: params[:resolution_notes]
          )
          resolved_count += 1
        end

        {
          success: true,
          message: "#{resolved_count} alerts resolved successfully"
        }
      end

      def dismiss_alerts(alerts, params)
        dismissed_count = 0
        alerts.find_each do |alert|
          alert.update!(
            status: 'dismissed',
            dismissed_at: Time.current,
            dismissal_reason: params[:dismissal_reason]
          )
          dismissed_count += 1
        end

        {
          success: true,
          message: "#{dismissed_count} alerts dismissed successfully"
        }
      end

      def delete_alerts(alerts)
        deleted_count = alerts.count
        alerts.destroy_all

        {
          success: true,
          message: "#{deleted_count} alerts deleted successfully"
        }
      end
    end
  end
end
