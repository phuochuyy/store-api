# frozen_string_literal: true

module Orders
  class OrderCancelledNotificationService
    class << self
      # Send order cancelled notification
      # @param order [Order] Order to send notification for
      # @param reason [String] Cancellation reason
      # @return [Hash] Result with success status
      def send_notification(order, reason = nil)
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order, reason)
        send_email_notification(order, reason) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Order cancelled notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Order cancelled notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send order cancelled notification',
          details: e.message
        }
      end

      private

      def create_notification(order, reason)
        reason_message = reason.present? ? " Reason: #{reason}." : ''

        Notification.create!(
          user: order.user,
          notification_type: 'order_cancelled',
          title: 'Order Cancelled',
          message: "Your order ##{order.id} has been cancelled.#{reason_message}",
          metadata: {
            order_id: order.id,
            cancelled_at: Time.current.iso8601,
            cancellation_reason: reason
          }
        )
      end

      def send_email_notification(order, _reason)
        # Email notification logic would go here
        Rails.logger.info "Sending order cancelled email for order #{order.id}"
      end
    end
  end
end
