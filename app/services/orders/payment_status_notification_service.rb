# frozen_string_literal: true

module Orders
  class PaymentStatusNotificationService
    class << self
      # Send payment status notification
      # @param order [Order] Order to send notification for
      # @param payment_status [String] Payment status
      # @return [Hash] Result with success status
      def send_notification(order, payment_status)
        return { success: false, error: 'Order not found' } unless order

        notification = create_notification(order, payment_status)
        send_email_notification(order, payment_status) if order.user.email_notifications_enabled?

        {
          success: true,
          notification: notification,
          message: 'Payment status notification sent successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Payment status notification error: #{e.message}"
        {
          success: false,
          error: 'Failed to send payment status notification',
          details: e.message
        }
      end

      private

      def create_notification(order, payment_status)
        status_message = build_status_message(payment_status)

        Notification.create!(
          user: order.user,
          notification_type: 'payment_status_update',
          title: 'Payment Status Update',
          message: "Payment status for order ##{order.id} has been updated. #{status_message}",
          metadata: {
            order_id: order.id,
            payment_status: payment_status,
            updated_at: Time.current.iso8601
          }
        )
      end

      def build_status_message(payment_status)
        case payment_status
        when 'completed'
          'Payment has been completed successfully.'
        when 'failed'
          'Payment has failed. Please try again.'
        when 'refunded'
          'Payment has been refunded.'
        when 'partially_refunded'
          'Payment has been partially refunded.'
        else
          "Payment status is now: #{payment_status}."
        end
      end

      def send_email_notification(order, payment_status)
        # Email notification logic would go here
        Rails.logger.info "Sending payment status email for order #{order.id}"
      end
    end
  end
end
