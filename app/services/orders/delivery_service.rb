# frozen_string_literal: true

module Orders
  class DeliveryService
    class << self
      # Deliver an order
      # @param order [Order] The order to deliver
      # @param delivered_by [User] The user delivering the order
      # @param delivery_notes [String] Notes about the delivery
      # @param delivery_signature [String] Delivery signature/confirmation
      # @return [Hash] Result with success status and details
      def deliver_order(order, delivered_by, delivery_notes: nil, delivery_signature: nil)
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'User not found' } unless delivered_by

        # Validate order can be delivered
        validation_result = validate_order_for_delivery(order)
        return validation_result unless validation_result[:success]

        # Perform delivery in transaction
        ActiveRecord::Base.transaction do
          # Update order status and delivery details
          order.update!(
            status: 'delivered',
            delivered_at: Time.current,
            delivery_notes: delivery_notes,
            delivery_signature: delivery_signature
          )

          # Create delivery notification
          create_delivery_notification(order, delivered_by, delivery_notes)

          # Log the delivery action
          Rails.logger.info "Order #{order.id} delivered by user #{delivered_by.id}. Notes: #{delivery_notes}"
        end

        { success: true, message: 'Order delivered successfully' }
      rescue StandardError => e
        Rails.logger.error "Order delivery error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Failed to deliver order', details: e.message }
      end

      private

      # Validate if order can be delivered
      # @param order [Order] The order to validate
      # @return [Hash] Validation result
      def validate_order_for_delivery(order)
        return { success: false, error: 'Order not found' } unless order

        # Check if order is in shipped status
        unless order.can_be_delivered?
          return {
            success: false,
            error: 'Order cannot be delivered',
            details: "Order is currently #{order.status}. Only shipped orders can be delivered."
          }
        end

        # Check if order has items
        if order.order_items.empty?
          return {
            success: false,
            error: 'Order cannot be delivered',
            details: 'Order has no items'
          }
        end

        { success: true }
      end

      # Create notification for order delivery
      # @param order [Order] The delivered order
      # @param delivered_by [User] The user who delivered the order
      # @param delivery_notes [String] Delivery notes
      def create_delivery_notification(order, delivered_by, delivery_notes)
        # Create notification for customer
        if order.user
          Notification.create!(
            user: order.user,
            notification_type: 'order_delivered',
            title: 'Order Delivered',
            message: "Your order ##{order.id} has been delivered successfully!",
            metadata: {
              order_id: order.id,
              delivered_at: order.delivered_at.iso8601,
              delivered_by: delivered_by.name,
              delivery_notes: delivery_notes
            }
          )
        end

        # Create notification for other admins
        User.admin.where.not(id: delivered_by.id).find_each do |admin|
          Notification.create!(
            user: admin,
            notification_type: 'order_delivered_admin',
            title: 'Order Delivered',
            message: "Order ##{order.id} has been delivered by #{delivered_by.name}",
            metadata: {
              order_id: order.id,
              delivered_at: order.delivered_at.iso8601,
              delivered_by: delivered_by.name,
              delivery_notes: delivery_notes
            }
          )
        end
      end
    end
  end
end
