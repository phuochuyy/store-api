# frozen_string_literal: true

module Orders
  class OrderConfirmationService
    class << self
      # Confirm an order
      # @param order [Order] The order to confirm
      # @param confirmed_by [User] The user confirming the order
      # @return [Hash] Result with success status and details
      def confirm_order(order, confirmed_by)
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'User not found' } unless confirmed_by

        validation_result = validate_order_for_confirmation(order)
        return validation_result unless validation_result[:success]

        # Perform confirmation in transaction
        ActiveRecord::Base.transaction do
          order.update!(status: 'confirmed', confirmed_at: Time.current)

          create_confirmation_notification(order, confirmed_by)

          # Log the confirmation action
          Rails.logger.info "Order #{order.id} confirmed by user #{confirmed_by.id}"
        end

        { success: true, message: 'Order confirmed successfully' }
      rescue StandardError => e
        Rails.logger.error "Order confirmation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Failed to confirm order', details: e.message }
      end

      private

      # @param order [Order] The order to validate
      # @return [Hash] Validation result
      def validate_order_for_confirmation(order)
        return { success: false, error: 'Order not found' } unless order

        unless order.pending?
          return {
            success: false,
            error: 'Order cannot be confirmed',
            details: "Order is currently #{order.status}. Only pending orders can be confirmed."
          }
        end

        if order.order_items.empty?
          return {
            success: false,
            error: 'Order cannot be confirmed',
            details: 'Order has no items'
          }
        end

        unavailable_items = check_item_availability(order)
        unless unavailable_items.empty?
          return {
            success: false,
            error: 'Order cannot be confirmed',
            details: "Some items are no longer available: #{unavailable_items.join(', ')}"
          }
        end

        { success: true }
      end

      # @param order [Order] The order to check
      # @return [Array] List of unavailable items
      def check_item_availability(order)
        unavailable_items = []

        order.order_items.each do |item|
          product = item.product
          if product.nil?
            unavailable_items << "Product ID #{item.product_id}"
          elsif product.stock_quantity < item.quantity
            unavailable_items << product.name
          end
        end

        unavailable_items
      end

      # @param order [Order] The confirmed order
      # @param confirmed_by [User] The user who confirmed the order
      def create_confirmation_notification(order, confirmed_by)
        if order.user
          Notification.create!(
            user: order.user,
            notification_type: 'order_confirmed',
            title: 'Order Confirmed',
            message: "Your order ##{order.id} has been confirmed and is being processed.",
            metadata: {
              order_id: order.id,
              confirmed_by: confirmed_by.name,
              confirmed_at: Time.current.iso8601
            }
          )
        end

        admin_users = User.where(role: 'admin')
        admin_users.each do |admin|
          next if admin.id == confirmed_by.id # Don't notify the person who confirmed

          Notification.create!(
            user: admin,
            notification_type: 'order_confirmed_admin',
            title: 'Order Confirmed',
            message: "Order ##{order.id} has been confirmed by #{confirmed_by.name}.",
            metadata: {
              order_id: order.id,
              confirmed_by: confirmed_by.name,
              confirmed_at: Time.current.iso8601,
              customer_name: order.customer_name,
              total_amount: order.total_amount
            }
          )
        end
      end
    end
  end
end
