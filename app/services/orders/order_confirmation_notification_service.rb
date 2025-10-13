# frozen_string_literal: true

module Orders
  class OrderConfirmationNotificationService
    class << self
      # Send order confirmation notification
      # @param order [Order] Order to send notification for
      # @return [Hash] Result with success status
      def send_notification(order)
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order)
        send_email_notification(order) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Order confirmation notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Order confirmation notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send order confirmation notification',
          details: e.message
        }
      end

      private

      def create_notification(order)
        Notification.create!(
          user: order.user,
          notification_type: 'order_confirmed',
          title: 'Order Confirmed',
          message: "Your order ##{order.id} has been confirmed and is being processed.",
          metadata: {
            order_id: order.id,
            order_total: order.total_amount,
            order_status: order.status,
            confirmed_at: Time.current.iso8601
          }
        )
      end

      def send_email_notification(order)
        # Email notification logic would go here
        # For now, just log it
        Rails.logger.info "Sending order confirmation email for order #{order.id}"
      end
    end
  end
end
