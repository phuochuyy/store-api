# frozen_string_literal: true

module Orders
  class ShippingService
    class << self
      # Ship an order
      # @param order [Order] The order to ship
      # @param shipped_by [User] The user shipping the order
      # @param tracking_number [String] Tracking number for the shipment
      # @param carrier [String] Shipping carrier name
      # @return [Hash] Result with success status and details
      def ship_order(order, shipped_by, tracking_number: nil, carrier: nil)
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'User not found' } unless shipped_by

        # Validate order can be shipped
        validation_result = validate_order_for_shipping(order)
        return validation_result unless validation_result[:success]

        # Perform shipping in transaction
        ActiveRecord::Base.transaction do
          # Update order status and shipping details
          order.update!(
            status: 'shipped',
            shipped_at: Time.current,
            tracking_number: tracking_number,
            carrier: carrier
          )

          # Create shipping notification
          create_shipping_notification(order, shipped_by, tracking_number, carrier)

          # Log the shipping action
          Rails.logger.info "Order #{order.id} shipped by user #{shipped_by.id}. Tracking: #{tracking_number}, Carrier: #{carrier}"
        end

        { success: true, message: 'Order shipped successfully' }
      rescue StandardError => e
        Rails.logger.error "Order shipping error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        { success: false, error: 'Failed to ship order', details: e.message }
      end

      private

      # Validate if order can be shipped
      # @param order [Order] The order to validate
      # @return [Hash] Validation result
      def validate_order_for_shipping(order)
        return { success: false, error: 'Order not found' } unless order

        # Check if order is in confirmed status
        unless order.can_be_shipped?
          return {
            success: false,
            error: 'Order cannot be shipped',
            details: "Order is currently #{order.status}. Only confirmed orders can be shipped."
          }
        end

        # Check if order has items
        if order.order_items.empty?
          return {
            success: false,
            error: 'Order cannot be shipped',
            details: 'Order has no items'
          }
        end

        { success: true }
      end

      # Create notification for order shipping
      # @param order [Order] The shipped order
      # @param shipped_by [User] The user who shipped the order
      # @param tracking_number [String] Tracking number
      # @param carrier [String] Carrier name
      def create_shipping_notification(order, shipped_by, tracking_number, carrier)
        # Create notification for customer
        if order.user
          Notification.create!(
            user: order.user,
            notification_type: 'order_shipped',
            title: 'Order Shipped',
            message: "Your order ##{order.id} has been shipped. #{if tracking_number
                                                                    "Tracking number: #{tracking_number}"
                                                                  end}",
            metadata: {
              order_id: order.id,
              tracking_number: tracking_number,
              carrier: carrier,
              shipped_at: order.shipped_at.iso8601,
              shipped_by: shipped_by.name
            }
          )
        end

        # Create notification for other admins
        User.admin.where.not(id: shipped_by.id).find_each do |admin|
          Notification.create!(
            user: admin,
            notification_type: 'order_shipped_admin',
            title: 'Order Shipped',
            message: "Order ##{order.id} has been shipped by #{shipped_by.name}",
            metadata: {
              order_id: order.id,
              tracking_number: tracking_number,
              carrier: carrier,
              shipped_at: order.shipped_at.iso8601,
              shipped_by: shipped_by.name
            }
          )
        end
      end
    end
  end
end
