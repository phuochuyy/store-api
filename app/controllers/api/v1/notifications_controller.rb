# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < Api::V1::BaseController
      before_action :set_notification, only: %i[show update destroy mark_read mark_unread]
      before_action :authenticate_user!

      # GET /api/v1/notifications
      def index
        filters = {
          notification_type: params[:notification_type],
          read: params[:read],
          start_date: params[:start_date],
          end_date: params[:end_date]
        }

        notifications = current_user.notifications.includes(:user)

        # Apply filters
        if filters[:notification_type].present?
          notifications = notifications.where(notification_type: filters[:notification_type])
        end
        notifications = notifications.where(read: filters[:read]) if filters[:read].present?

        # Date range filters
        if filters[:start_date].present? && filters[:end_date].present?
          start_date = Date.parse(filters[:start_date])
          end_date = Date.parse(filters[:end_date])
          notifications = notifications.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        end

        # Order by recency
        notifications = notifications.recent

        # Pagination
        page = params[:page] || 1
        per_page = params[:per_page] || 20
        total_count = notifications.count
        notifications = notifications.page(page).per(per_page)

        data = {
          notifications: notifications.map { |notification| notification_serializer(notification) },
          pagination: {
            current_page: notifications.current_page,
            total_pages: notifications.total_pages,
            total_count: total_count,
            per_page: per_page
          },
          unread_count: current_user.notifications.unread.count
        }

        render_success(data, 'Notifications retrieved successfully')
      end

      # GET /api/v1/notifications/:id
      def show
        data = { notification: notification_serializer(@notification) }
        render_success(data, 'Notification retrieved successfully')
      end

      # PATCH/PUT /api/v1/notifications/:id
      def update
        update_params = notification_params.except(:read, :read_at)

        if @notification.update(update_params)
          data = { notification: notification_serializer(@notification) }
          render_success(data, 'Notification updated successfully')
        else
          render_error('Failed to update notification', :unprocessable_entity, @notification.errors.full_messages)
        end
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        if @notification.destroy
          render_success(nil, 'Notification deleted successfully')
        else
          render_error('Failed to delete notification', :unprocessable_entity, @notification.errors.full_messages)
        end
      end

      # POST /api/v1/notifications/:id/mark_read
      def mark_read
        @notification.mark_as_read!
        data = { notification: notification_serializer(@notification) }
        render_success(data, 'Notification marked as read')
      end

      # POST /api/v1/notifications/:id/mark_unread
      def mark_unread
        @notification.mark_as_unread!
        data = { notification: notification_serializer(@notification) }
        render_success(data, 'Notification marked as unread')
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        count = Notification.mark_all_as_read_for_user(current_user)
        render_success({ count: count }, "#{count} notifications marked as read")
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        count = Notification.get_unread_count_for_user(current_user)
        render_success({ unread_count: count }, 'Unread count retrieved successfully')
      end

      # GET /api/v1/notifications/recent
      def recent
        limit = params[:limit] || 10
        notifications = Notification.get_recent_notifications_for_user(current_user, limit)
        data = {
          notifications: notifications.map { |notification| notification_serializer(notification) },
          count: notifications.count
        }
        render_success(data, 'Recent notifications retrieved successfully')
      end

      # GET /api/v1/notifications/statistics
      def statistics
        period = params[:period] || 'week'
        result = StockAlerts::StockNotificationService.get_notification_statistics(period)

        if result[:success]
          render_success(result, 'Notification statistics retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # Admin-only endpoints
      before_action :admin_only!, only: %i[send_stock_alerts send_daily_summary send_pending]

      # POST /api/v1/notifications/send_stock_alerts
      def send_stock_alerts
        alert_ids = params[:alert_ids]
        return render_error('Alert IDs are required', :bad_request) unless alert_ids.present?

        stock_alerts = StockAlert.where(id: alert_ids)
        return render_error('No valid stock alerts found', :not_found) if stock_alerts.empty?

        result = StockAlerts::StockNotificationService.send_bulk_stock_alert_notifications(stock_alerts)

        if result[:success]
          render_success(result, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # POST /api/v1/notifications/send_daily_summary
      def send_daily_summary
        result = StockAlerts::StockNotificationService.send_daily_stock_alert_summary

        if result[:success]
          render_success(result, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # POST /api/v1/notifications/send_pending
      def send_pending
        result = StockAlerts::StockNotificationService.send_pending_notifications

        if result[:success]
          render_success(result, result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      private

      def set_notification
        @notification = current_user.notifications.find_by(id: params[:id])
        render_error('Notification not found', :not_found) unless @notification
      end

      def notification_params
        params.require(:notification).permit(
          :notification_type,
          :title,
          :message,
          :read,
          :read_at,
          metadata: {}
        )
      end

      def notification_serializer(notification)
        {
          id: notification.id,
          notification_type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          read: notification.read,
          read_at: notification.read_at,
          sent_at: notification.sent_at,
          metadata: notification.metadata,
          created_at: notification.created_at,
          updated_at: notification.updated_at,
          user: {
            id: notification.user.id,
            name: notification.user.name,
            email: notification.user.email
          }
        }
      end
    end
  end
end
