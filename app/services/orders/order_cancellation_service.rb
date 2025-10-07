# frozen_string_literal: true

module Orders
  class OrderCancellationService
    class << self
      # Cancel an order
      # @param order [Order] The order to cancel
      # @param cancelled_by [User] The user cancelling the order
      # @param reason [String] Reason for cancellation
      # @return [Hash] Result with success status and details
      def cancel_order(order, cancelled_by, reason = nil)
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'User not found' } unless cancelled_by

        # Validate order can be cancelled
        validation_result = validate_order_for_cancellation(order)
        return validation_result unless validation_result[:success]

        # Perform cancellation in transaction
        ActiveRecord::Base.transaction do
          # Restore stock quantities
          restore_stock_quantities(order)

          # Update order status
          order.update!(
            status: 'cancelled',
            cancelled_at: Time.current,
            cancellation_reason: reason
          )

          # Create cancellation notification
          create_cancellation_notification(order, cancelled_by, reason)

          # Log the cancellation action
          Rails.logger.info "Order #{order.id} cancelled by user #{cancelled_by.id}. Reason: #{reason}"
        end

        { success: true, message: 'Order cancelled successfully' }
      rescue StandardError => e
        Rails.logger.error "Order cancellation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Failed to cancel order', details: e.message }
      end

      private

      # Validate if order can be cancelled
      # @param order [Order] The order to validate
      # @return [Hash] Validation result
      def validate_order_for_cancellation(order)
        # Check if order exists
        return { success: false, error: 'Order not found' } unless order

        # Check if order can be cancelled (not already delivered or cancelled)
        unless order.can_be_cancelled?
          return {
            success: false,
            error: 'Order cannot be cancelled',
            details: "Order is currently #{order.status}. Only pending, confirmed, or shipped orders can be cancelled."
          }
        end

        { success: true }
      end

      # Restore stock quantities for cancelled order
      # @param order [Order] The order being cancelled
      def restore_stock_quantities(order)
        order.order_items.each do |item|
          product = item.product
          next unless product

          # Restore the stock quantity
          product.add_stock(item.quantity)

          Rails.logger.info "Restored #{item.quantity} units of #{product.name} to stock"
        end
      end

      # Create notification for order cancellation
      # @param order [Order] The cancelled order
      # @param cancelled_by [User] The user who cancelled the order
      # @param reason [String] Reason for cancellation
      def create_cancellation_notification(order, cancelled_by, reason)
        # Create notification for customer if order has a user
        if order.user
          Notification.create!(
            user: order.user,
            notification_type: 'order_cancelled',
            title: 'Order Cancelled',
            message: "Your order ##{order.id} has been cancelled.#{" Reason: #{reason}" if reason}",
            metadata: {
              order_id: order.id,
              cancelled_by: cancelled_by.name,
              cancelled_at: Time.current.iso8601,
              reason: reason
            }
          )
        end

        # Create admin notification
        admin_users = User.where(role: 'admin')
        admin_users.each do |admin|
          next if admin.id == cancelled_by.id # Don't notify the person who cancelled

          Notification.create!(
            user: admin,
            notification_type: 'order_cancelled_admin',
            title: 'Order Cancelled',
            message: "Order ##{order.id} has been cancelled by #{cancelled_by.name}.#{" Reason: #{reason}" if reason}",
            metadata: {
              order_id: order.id,
              cancelled_by: cancelled_by.name,
              cancelled_at: Time.current.iso8601,
              reason: reason,
              customer_name: order.customer_name,
              total_amount: order.total_amount
            }
          )
        end
      end
    end
  end
end
