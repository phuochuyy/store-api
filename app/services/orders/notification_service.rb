# frozen_string_literal: true

module Orders
  class NotificationService
    class << self
      # Send order confirmation notification
      # @param order [Order] Order to send notification for
      # @return [Hash] Result with success status
      def send_order_confirmation(order)
        OrderConfirmationNotificationService.send_notification(order)
      end

      # Send order shipped notification
      # @param order [Order] Order to send notification for
      # @param tracking_info [Hash] Tracking information
      # @return [Hash] Result with success status
      def send_order_shipped(order, tracking_info = {})
        OrderShippedNotificationService.send_notification(order, tracking_info)
      end

      # Send order delivered notification
      # @param order [Order] Order to send notification for
      # @param delivery_info [Hash] Delivery information
      # @return [Hash] Result with success status
      def send_order_delivered(order, delivery_info = {})
        OrderDeliveredNotificationService.send_notification(order, delivery_info)
      end

      # Send order cancelled notification
      # @param order [Order] Order to send notification for
      # @param reason [String] Cancellation reason
      # @return [Hash] Result with success status
      def send_order_cancelled(order, reason = nil)
        OrderCancelledNotificationService.send_notification(order, reason)
      end

      # Send payment status notification
      # @param order [Order] Order to send notification for
      # @param payment_status [String] Payment status
      # @return [Hash] Result with success status
      def send_payment_status(order, payment_status)
        PaymentStatusNotificationService.send_notification(order, payment_status)
      end

      # Send order reminder notification
      # @param order [Order] Order to send notification for
      # @param reminder_type [String] Type of reminder
      # @return [Hash] Result with success status
      def send_order_reminder(order, reminder_type = 'review')
        OrderReminderNotificationService.send_notification(order, reminder_type)
      end

      # Send bulk order notifications
      # @param orders [Array<Order>] Orders to send notifications for
      # @param notification_type [String] Type of notification
      # @return [Hash] Result with success status
      def send_bulk_order_notifications(orders, notification_type)
        BulkOrderNotificationService.send_notifications(orders, notification_type)
      end
    end
  end
end
