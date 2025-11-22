# frozen_string_literal: true

module Orders
  class OrderCreationService
    class << self
      # @param order_params [Hash] Order parameters
      # @param order_items_params [Array<Hash>] Order items parameters
      # @return [Hash] Result with success status and order information
      def create_order(order_params, order_items_params = [])
        order = Order.new(order_params)

        if order.save
          add_order_items(order, order_items_params) if order_items_params.present?
          order.update_total_amount

          {
            success: true,
            order: order,
            message: 'Order created successfully'
          }
        else
          {
            success: false,
            error: 'Failed to create order',
            details: order.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Order creation error: #{e.message}"
        {
          success: false,
          error: 'Failed to create order',
          details: e.message
        }
      end

      private

      def add_order_items(order, order_items_params)
        order_items_params.each do |item_params|
          product = Product.find(item_params[:product_id])
          order.order_items.create!(
            product: product,
            quantity: item_params[:quantity].to_i,
            unit_price: product.price
          )
          # reduce_stock returns false if stock is insufficient, but we still want to reduce stock
          # if stock is sufficient. If reduce_stock fails, we should handle it.
          result = product.reduce_stock(item_params[:quantity].to_i)
          unless result
            Rails.logger.warn "Failed to reduce stock for product #{product.id}: insufficient stock"
            # Don't raise exception, but log the warning
          end
        end
      end
    end
  end
end
