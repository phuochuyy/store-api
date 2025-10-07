# frozen_string_literal: true

module Orders
  class NotificationService
    class << self
      # Send order confirmation notification
      # @param order [Order] Order to send notification for
      # @return [Hash] Result with success status
      def send_order_confirmation(order)
        return { success: false, error: 'Order not found' } unless order

        # Create notification for customer
        notification = Notification.create!(
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

        # Send email notification if enabled
        send_order_confirmation_email(order) if order.user.email_notifications_enabled?

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

      # Send order shipped notification
      # @param order [Order] Order to send notification for
      # @param tracking_info [Hash] Tracking information
      # @return [Hash] Result with success status
      def send_order_shipped(order, tracking_info = {})
        return { success: false, error: 'Order not found' } unless order

        tracking_message = if tracking_info[:tracking_number].present?
                             "Tracking number: #{tracking_info[:tracking_number]}"
                           else
                             'Tracking information will be available soon'
                           end

        # Create notification for customer
        notification = Notification.create!(
          user: order.user,
          notification_type: 'order_shipped',
          title: 'Order Shipped',
          message: "Your order ##{order.id} has been shipped. #{tracking_message}",
          metadata: {
            order_id: order.id,
            tracking_number: tracking_info[:tracking_number],
            carrier: tracking_info[:carrier],
            shipped_at: order.shipped_at,
            estimated_delivery: order.estimated_delivery_date
          }
        )

        # Send email notification if enabled
        send_order_shipped_email(order, tracking_info) if order.user.email_notifications_enabled?

        # Send SMS notification if enabled and phone available
        if order.user.sms_notifications_enabled? && order.user.phone.present?
          send_order_shipped_sms(order, tracking_info)
        end

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

      # Send order delivered notification
      # @param order [Order] Order to send notification for
      # @param delivery_info [Hash] Delivery information
      # @return [Hash] Result with success status
      def send_order_delivered(order, delivery_info = {})
        return { success: false, error: 'Order not found' } unless order

        # Create notification for customer
        notification = Notification.create!(
          user: order.user,
          notification_type: 'order_delivered',
          title: 'Order Delivered',
          message: "Your order ##{order.id} has been delivered successfully. Thank you for your purchase!",
          metadata: {
            order_id: order.id,
            delivered_at: order.delivered_at,
            delivery_notes: delivery_info[:delivery_notes],
            delivery_signature: delivery_info[:delivery_signature]
          }
        )

        # Send email notification if enabled
        send_order_delivered_email(order, delivery_info) if order.user.email_notifications_enabled?

        # Send SMS notification if enabled
        if order.user.sms_notifications_enabled? && order.user.phone.present?
          send_order_delivered_sms(order, delivery_info)
        end

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

      # Send order cancelled notification
      # @param order [Order] Order to send notification for
      # @param reason [String] Cancellation reason
      # @return [Hash] Result with success status
      def send_order_cancelled(order, reason = nil)
        return { success: false, error: 'Order not found' } unless order

        reason_message = reason.present? ? " Reason: #{reason}" : ''

        # Create notification for customer
        notification = Notification.create!(
          user: order.user,
          notification_type: 'order_cancelled',
          title: 'Order Cancelled',
          message: "Your order ##{order.id} has been cancelled.#{reason_message}",
          metadata: {
            order_id: order.id,
            cancelled_at: Time.current.iso8601,
            cancellation_reason: reason,
            refund_amount: order.total_amount
          }
        )

        # Send email notification if enabled
        send_order_cancelled_email(order, reason) if order.user.email_notifications_enabled?

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

      # Send payment status notification
      # @param order [Order] Order to send notification for
      # @param payment_status [String] Payment status
      # @return [Hash] Result with success status
      def send_payment_status(order, payment_status)
        return { success: false, error: 'Order not found' } unless order

        status_messages = {
          'paid' => 'Your payment has been processed successfully',
          'failed' => 'Your payment could not be processed',
          'refunded' => 'Your payment has been refunded',
          'pending' => 'Your payment is being processed'
        }

        message = status_messages[payment_status] || "Your payment status has been updated to #{payment_status}"

        # Create notification for customer
        notification = Notification.create!(
          user: order.user,
          notification_type: 'payment_update',
          title: 'Payment Update',
          message: "Order ##{order.id}: #{message}",
          metadata: {
            order_id: order.id,
            payment_status: payment_status,
            updated_at: Time.current.iso8601
          }
        )

        # Send email notification if enabled
        send_payment_status_email(order, payment_status) if order.user.email_notifications_enabled?

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

      # Send order reminder notification
      # @param order [Order] Order to send reminder for
      # @param reminder_type [String] Type of reminder
      # @return [Hash] Result with success status
      def send_order_reminder(order, reminder_type = 'review')
        return { success: false, error: 'Order not found' } unless order

        reminder_messages = {
          'review' => "How was your experience with order ##{order.id}? Please leave a review!",
          'reorder' => "Loved your order ##{order.id}? Reorder your favorite items now!",
          'feedback' => "We'd love to hear your feedback about order ##{order.id}"
        }

        message = reminder_messages[reminder_type] || "Reminder about your order ##{order.id}"

        # Create notification for customer
        notification = Notification.create!(
          user: order.user,
          notification_type: 'order_reminder',
          title: 'Order Reminder',
          message: message,
          metadata: {
            order_id: order.id,
            reminder_type: reminder_type,
            sent_at: Time.current.iso8601
          }
        )

        # Send email notification if enabled
        send_order_reminder_email(order, reminder_type) if order.user.email_notifications_enabled?

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

      # Get order notification history
      # @param order [Order] Order to get notifications for
      # @return [Hash] Notification history
      def get_order_notifications(order)
        return { success: false, error: 'Order not found' } unless order

        notifications = order.user.notifications
                             .where(metadata: { order_id: order.id })
                             .recent

        {
          success: true,
          notifications: notifications.map { |notification| notification_data(notification) },
          total_count: notifications.count
        }
      end

      # Send bulk order notifications
      # @param orders [Array<Order>] Orders to send notifications for
      # @param notification_type [String] Type of notification
      # @return [Hash] Bulk notification result
      def send_bulk_order_notifications(orders, notification_type)
        results = {
          total: orders.size,
          successful: 0,
          failed: 0,
          errors: []
        }

        orders.each do |order|
          result = case notification_type
                   when 'confirmation'
                     send_order_confirmation(order)
                   when 'shipped'
                     send_order_shipped(order)
                   when 'delivered'
                     send_order_delivered(order)
                   when 'cancelled'
                     send_order_cancelled(order)
                   else
                     { success: false, error: 'Invalid notification type' }
                   end

          if result[:success]
            results[:successful] += 1
          else
            results[:failed] += 1
            results[:errors] << "Order #{order.id}: #{result[:error]}"
          end
        end

        {
          success: results[:failed] == 0,
          results: results,
          message: "Bulk notifications sent: #{results[:successful]} successful, #{results[:failed]} failed"
        }
      end

      private

      # Send order confirmation email
      def send_order_confirmation_email(order)
        Rails.logger.info "Order confirmation email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send order shipped email
      def send_order_shipped_email(order, tracking_info)
        Rails.logger.info "Order shipped email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send order delivered email
      def send_order_delivered_email(order, delivery_info)
        Rails.logger.info "Order delivered email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send order cancelled email
      def send_order_cancelled_email(order, reason)
        Rails.logger.info "Order cancelled email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send payment status email
      def send_payment_status_email(order, payment_status)
        Rails.logger.info "Payment status email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send order reminder email
      def send_order_reminder_email(order, reminder_type)
        Rails.logger.info "Order reminder email sent to #{order.user.email} for order #{order.id}"
        # Implement email sending logic
      end

      # Send order shipped SMS
      def send_order_shipped_sms(order, tracking_info)
        Rails.logger.info "Order shipped SMS sent to #{order.user.phone} for order #{order.id}"
        # Implement SMS sending logic
      end

      # Send order delivered SMS
      def send_order_delivered_sms(order, delivery_info)
        Rails.logger.info "Order delivered SMS sent to #{order.user.phone} for order #{order.id}"
        # Implement SMS sending logic
      end

      # Generate notification data hash
      def notification_data(notification)
        {
          id: notification.id,
          notification_type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          read: notification.read,
          metadata: notification.metadata,
          created_at: notification.created_at,
          updated_at: notification.updated_at
        }
      end
    end
  end
end
