# frozen_string_literal: true

module Orders
  class OrderReminderNotificationService
    class << self
      # Send order reminder notification
      # @param order [Order] Order to send notification for
      # @param reminder_type [String] Type of reminder
      # @return [Hash] Result with success status
      def send_notification(order, reminder_type = 'review')
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order, reminder_type)
        send_email_notification(order, reminder_type) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Order reminder notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Order reminder notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send order reminder notification',
          details: e.message
        }
      end

      private

      def create_notification(order, reminder_type)
        reminder_message = build_reminder_message(reminder_type)

        Notification.create!(
          user: order.user,
          notification_type: 'order_reminder',
          title: 'Order Reminder',
          message: "Reminder for order ##{order.id}: #{reminder_message}",
          metadata: {
            order_id: order.id,
            reminder_type: reminder_type,
            sent_at: Time.current.iso8601
          }
        )
      end

      def build_reminder_message(reminder_type)
        case reminder_type
        when 'review'
          'Please leave a review for your recent order.'
        when 'reorder'
          'Consider reordering your favorite items.'
        when 'feedback'
          'We would love to hear your feedback about your order.'
        else
          'Thank you for your order!'
        end
      end

      def send_email_notification(order, _reminder_type)
        # Email notification logic would go here
        Rails.logger.info "Sending order reminder email for order #{order.id}"
      end
    end
  end
end
