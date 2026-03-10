# frozen_string_literal: true

module Orders
  class BulkOrderNotificationService
    class << self
      # Send bulk order notifications
      # @param orders [Array<Order>] Orders to send notifications for
      # @param notification_type [String] Type of notification
      # @return [Hash] Result with success status
      def send_notifications(orders, notification_type)
        return { success: false, error: 'No orders provided' } if orders.blank?

        notifications = []
        errors = []

        orders.each do |order|
          result = send_single_notification(order, notification_type)
          if result[:success]
            notifications << result[:notification]
          else
            errors << { order_id: order.id, error: result[:error] }
          end
        end

        {
          success: errors.empty?,
          notifications: notifications,
          errors: errors,
          message: "Bulk notifications sent: #{notifications.count} successful, #{errors.count} failed"
        }
      rescue StandardError => e
        Rails.logger.error "Bulk order notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send bulk order notifications',
          details: e.message
        }
      end

      private

      def send_single_notification(order, notification_type)
        case notification_type
        when 'order_confirmed'
          OrderConfirmationNotificationService.send_notification(order)
        when 'order_shipped'
          OrderShippedNotificationService.send_notification(order)
        when 'order_delivered'
          OrderDeliveredNotificationService.send_notification(order)
        when 'order_cancelled'
          OrderCancelledNotificationService.send_notification(order)
        when 'payment_status_update'
          PaymentStatusNotificationService.send_notification(order, 'completed')
        when 'order_reminder'
          OrderReminderNotificationService.send_notification(order)
        else
          { success: false, error: "Unknown notification type: #{notification_type}" }
        end
      end
    end
  end
end
