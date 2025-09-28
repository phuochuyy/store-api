# frozen_string_literal: true

module Api
  module V1
    class StockAlertsController < Api::V1::BaseController
      before_action :set_stock_alert, only: %i[show update destroy resolve dismiss]
      before_action :admin_only!, only: %i[index show update destroy resolve dismiss bulk_operation statistics]

      # GET /api/v1/stock_alerts
      def index
        filters = {
          status: params[:status],
          alert_type: params[:alert_type],
          product_id: params[:product_id],
          notification_sent: params[:notification_sent],
          start_date: params[:start_date],
          end_date: params[:end_date],
          severity: params[:severity]
        }

        result = StockAlerts::StockAlertService.get_alerts(
          filters: filters,
          page: params[:page] || 1,
          per_page: params[:per_page] || 20
        )

        if result[:success]
          render_success(result, 'Stock alerts retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/stock_alerts/:id
      def show
        data = {
          alert: alert_serializer(@stock_alert),
          product: product_serializer(@stock_alert.product)
        }

        render_success(data, 'Stock alert retrieved successfully')
      end

      # PATCH/PUT /api/v1/stock_alerts/:id
      def update
        update_params = stock_alert_params.except(:resolved_by, :resolution_notes, :dismissed_by, :dismissal_reason)

        result = StockAlerts::StockAlertService.update_alert(@stock_alert, update_params)

        if result[:success]
          data = { alert: alert_serializer(result[:alert]) }
          render_success(data, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # DELETE /api/v1/stock_alerts/:id
      def destroy
        if @stock_alert.destroy
          render_success(nil, 'Stock alert deleted successfully')
        else
          render_error('Failed to delete stock alert', :unprocessable_entity, @stock_alert.errors.full_messages)
        end
      end

      # POST /api/v1/stock_alerts/:id/resolve
      def resolve
        result = StockAlerts::StockAlertService.resolve_alert(
          @stock_alert,
          resolved_by: current_user&.name || 'System',
          resolution_notes: params[:resolution_notes]
        )

        if result[:success]
          data = { alert: alert_serializer(result[:alert]) }
          render_success(data, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # POST /api/v1/stock_alerts/:id/dismiss
      def dismiss
        result = StockAlerts::StockAlertService.dismiss_alert(
          @stock_alert,
          dismissed_by: current_user&.name || 'System',
          dismissal_reason: params[:dismissal_reason]
        )

        if result[:success]
          data = { alert: alert_serializer(result[:alert]) }
          render_success(data, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # POST /api/v1/stock_alerts/bulk_operation
      def bulk_operation
        alert_ids = params[:alert_ids]
        action = params[:action]
        operation_params = params[:operation_params] || {}

        result = StockAlerts::StockAlertService.bulk_operation(alert_ids, action, operation_params)

        if result[:success]
          render_success({ count: result[:count] }, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/stock_alerts/statistics
      def statistics
        period = params[:period] || 'month'
        result = StockAlerts::StockAlertService.get_alert_statistics(period)

        if result[:success]
          render_success(result, 'Stock alert statistics retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/stock_alerts/critical
      def critical
        alerts = StockAlerts::StockMonitoringService.get_critical_alerts
        data = {
          alerts: alerts.map { |alert| alert_serializer(alert) },
          count: alerts.count
        }

        render_success(data, 'Critical stock alerts retrieved successfully')
      end

      # GET /api/v1/stock_alerts/low_stock
      def low_stock
        alerts = StockAlerts::StockMonitoringService.get_low_stock_alerts
        data = {
          alerts: alerts.map { |alert| alert_serializer(alert) },
          count: alerts.count
        }

        render_success(data, 'Low stock alerts retrieved successfully')
      end

      # GET /api/v1/stock_alerts/pending_notifications
      def pending_notifications
        alerts = StockAlerts::StockMonitoringService.get_alerts_pending_notification
        data = {
          alerts: alerts.map { |alert| alert_serializer(alert) },
          count: alerts.count
        }

        render_success(data, 'Alerts pending notification retrieved successfully')
      end

      # POST /api/v1/stock_alerts/mark_notifications_sent
      def mark_notifications_sent
        alert_ids = params[:alert_ids]
        return render_error('Alert IDs are required', :bad_request) unless alert_ids.present?

        updated_count = StockAlerts::StockMonitoringService.mark_notifications_sent(alert_ids)

        render_success(
          { count: updated_count },
          "#{updated_count} alerts marked as notification sent"
        )
      end

      # GET /api/v1/stock_alerts/summary
      def summary
        summary_data = StockAlerts::StockMonitoringService.get_alert_summary
        render_success(summary_data, 'Stock alert summary retrieved successfully')
      end

      private

      def set_stock_alert
        @stock_alert = StockAlert.find_by(id: params[:id])
        render_error('Stock alert not found', :not_found) unless @stock_alert
      end

      def stock_alert_params
        params.require(:stock_alert).permit(
          :alert_type,
          :threshold,
          :status,
          :message,
          :resolved_by,
          :resolution_notes,
          :dismissed_by,
          :dismissal_reason,
          metadata: {}
        )
      end

      def alert_serializer(alert)
        {
          id: alert.id,
          product_id: alert.product_id,
          product_name: alert.product.name,
          product_sku: alert.product.id,
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

      def product_serializer(product)
        {
          id: product.id,
          name: product.name,
          description: product.description,
          price: product.price,
          stock_quantity: product.stock_quantity,
          stock_status: product.stock_status,
          stock_status_color: product.stock_status_color,
          stock_status_message: product.stock_status_message,
          brand: {
            id: product.brand.id,
            name: product.brand.name
          },
          category: {
            id: product.category.id,
            name: product.category.name
          }
        }
      end
    end
  end
end
