# frozen_string_literal: true

module Orders
  class OrderShippedNotificationService
    class << self
      # Send order shipped notification
      # @param order [Order] Order to send notification for
      # @param tracking_info [Hash] Tracking information
      # @return [Hash] Result with success status
      def send_notification(order, tracking_info = {})
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order, tracking_info)
        send_email_notification(order, tracking_info) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Order shipped notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Order shipped notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send order shipped notification',
          details: e.message
        }
      end

      private

      def create_notification(order, tracking_info)
        tracking_message = build_tracking_message(tracking_info)

        Notification.create!(
          user: order.user,
          notification_type: 'order_shipped',
          title: 'Order Shipped',
          message: "Your order ##{order.id} has been shipped. #{tracking_message}",
          metadata: {
            order_id: order.id,
            tracking_number: tracking_info[:tracking_number],
            carrier: tracking_info[:carrier],
            shipped_at: Time.current.iso8601
          }
        )
      end

      def build_tracking_message(tracking_info)
        if tracking_info[:tracking_number].present?
          carrier_info = tracking_info[:carrier].present? ? " via #{tracking_info[:carrier]}" : ''
          "Tracking number: #{tracking_info[:tracking_number]}#{carrier_info}."
        else
          'You will receive tracking information soon.'
        end
      end

      def send_email_notification(order, _tracking_info)
        # Email notification logic would go here
        Rails.logger.info "Sending order shipped email for order #{order.id}"
      end
    end
  end
end
