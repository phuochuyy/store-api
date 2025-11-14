module Api
  module V1
    class OrderItemsController < Api::V1::BaseController
      before_action :set_order_item, only: %i[show update destroy]
      before_action :set_order, only: %i[create index]

      def index
        @order_items = @order.order_items.includes(:product)
        render json: @order_items, include: :product
      end

      def show
        render json: @order_item, include: :product
      end

      def create
        @order_item = @order.order_items.build(order_item_params)

        # Set unit price from phone
        @order_item.unit_price = @order_item.phone.price

        if @order_item.save
          # Update order total
          @order.update_total_amount
          render json: @order_item, status: :created, include: :phone
        else
          render json: { errors: @order_item.errors }, status: :unprocessable_content
        end
      end

      def update
        if @order_item.update(order_item_params)
          # Update order total
          @order_item.order.update_total_amount
          render json: @order_item, include: :phone
        else
          render json: { errors: @order_item.errors }, status: :unprocessable_content
        end
      end

      def destroy
        order = @order_item.order
        @order_item.destroy
        # Update order total
        order.update_total_amount
        head :no_content
      end

      private

      def set_order_item
        @order_item = OrderItem.find_by(id: params[:id])
        render_error('Order item not found', :not_found) unless @order_item
      end

      def set_order
        @order = Order.find_by(id: params[:order_id])
        render_error('Order not found', :not_found) unless @order
      end

      def order_item_params
        params.expect(order_item: %i[product_id quantity])
      end
    end
  end
end
