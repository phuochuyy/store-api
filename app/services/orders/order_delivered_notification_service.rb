# frozen_string_literal: true

module Orders
  class OrderDeliveredNotificationService
    class << self
      # Send order delivered notification
      # @param order [Order] Order to send notification for
      # @param delivery_info [Hash] Delivery information
      # @return [Hash] Result with success status
      def send_notification(order, delivery_info = {})
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order, delivery_info)
        send_email_notification(order, delivery_info) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Order delivered notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Order delivered notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send order delivered notification',
          details: e.message
        }
      end

      private

      def create_notification(order, delivery_info)
        delivery_message = build_delivery_message(delivery_info)

        Notification.create!(
          user: order.user,
          notification_type: 'order_delivered',
          title: 'Order Delivered',
          message: "Your order ##{order.id} has been delivered. #{delivery_message}",
          metadata: {
            order_id: order.id,
            delivered_at: Time.current.iso8601,
            delivery_notes: delivery_info[:delivery_notes],
            delivery_signature: delivery_info[:delivery_signature]
          }
        )
      end

      def build_delivery_message(delivery_info)
        if delivery_info[:delivery_notes].present?
          "Delivery notes: #{delivery_info[:delivery_notes]}."
        else
          'Thank you for your order!'
        end
      end

      def send_email_notification(order, delivery_info)
        # Email notification logic would go here
        Rails.logger.info "Sending order delivered email for order #{order.id}"
      end
    end
  end
end
