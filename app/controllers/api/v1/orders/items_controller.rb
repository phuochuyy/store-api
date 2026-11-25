# frozen_string_literal: true

module Api
  module V1
    module Orders
      # The order's owner and admins can read its items. Changing them is admin only, like
      # updating or cancelling the order itself: customers shape an order through their cart
      # before checkout, not afterwards.
      class ItemsController < Api::V1::BaseController
        # admin_only! first, so a customer gets 403 on writes without the order being looked up.
        before_action :admin_only!, only: %i[create update destroy]
        before_action :set_order, only: %i[index create]
        before_action :set_order_item, only: %i[show update destroy]

        def index
          order_items = @order.order_items.includes(:product).map { |item| order_item_serializer(item) }
          render_success({ order_items: order_items }, 'Order items retrieved successfully')
        end

        def show
          render_success({ order_item: order_item_serializer(@order_item) }, 'Order item retrieved successfully')
        end

        # OrderItem prices the item from its variant or product and keeps the order total in sync.
        def create
          order_item = @order.order_items.build(order_item_create_params)

          if order_item.save
            render_success({ order_item: order_item_serializer(order_item) }, 'Order item added successfully', :created)
          else
            render_error('Order item could not be added', :unprocessable_content, order_item.errors.full_messages)
          end
        end

        # Only the quantity can change: swapping the product would keep the old unit price.
        def update
          if @order_item.update(order_item_update_params)
            render_success({ order_item: order_item_serializer(@order_item) }, 'Order item updated successfully')
          else
            render_error('Order item could not be updated', :unprocessable_content,
                         @order_item.errors.full_messages)
          end
        end

        def destroy
          @order_item.destroy!
          render_success(nil, 'Order item removed successfully')
        end

        private

        # Another user's order or item answers 404, not 403, so its existence is not confirmed.
        def set_order
          @order = Order.find_by(id: params[:order_id])
          render_error('Order not found', :not_found) unless @order && visible?(@order)
        end

        def set_order_item
          @order_item = OrderItem.find_by(id: params[:id])
          render_error('Order item not found', :not_found) unless @order_item && visible?(@order_item.order)
        end

        def visible?(order)
          current_user.admin? || order.user_id == current_user.id
        end

        def order_item_create_params
          params.expect(order_item: %i[product_id quantity])
        end

        def order_item_update_params
          params.expect(order_item: %i[quantity])
        end

        def order_item_serializer(order_item)
          ::Orders::OrderSerializerService.serialize_order_item(order_item)
        end
      end
    end
  end
end
