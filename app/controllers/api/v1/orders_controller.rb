module Api
  module V1
    class OrdersController < Api::V1::BaseController
      before_action :set_order, only: %i[show update destroy confirm cancel ship]
      before_action :admin_only!, only: %i[index update destroy confirm cancel ship]

      # GET /api/v1/orders (Admin only)
      def index
        @orders = Order.includes(:order_items, :products).recent
        @orders = @orders.page(params[:page]).per(params[:per_page] || 10)

        render json: {
          orders: @orders.map { |order| order_serializer(order) },
          pagination: {
            current_page: @orders.current_page,
            total_pages: @orders.total_pages,
            total_count: @orders.total_count,
            per_page: @orders.limit_value
          }
        }
      end

      # GET /api/v1/orders/:id
      def show
        render json: {
          order: order_serializer(@order),
          order_items: @order.order_items.map { |item| order_item_serializer(item) }
        }
      end

      # POST /api/v1/orders
      def create
        result = Orders::OrderCreationService.create_order(order_params, params[:order_items])

        if result[:success]
          render json: {
            message: result[:message],
            order: order_serializer(result[:order])
          }, status: :created
        else
          render json: {
            errors: result[:details]
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/orders/:id (Admin only)
      def update
        if @order.update(order_params)
          render json: {
            message: 'Order updated successfully',
            order: order_serializer(@order)
          }
        else
          render json: {
            errors: @order.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/orders/:id (Admin only)
      def destroy
        @order.destroy
        render json: { message: 'Order deleted successfully' }
      end

      # POST /api/v1/orders/:id/confirm (Admin only)
      def confirm
        result = Orders::OrderConfirmationService.confirm_order(@order, current_user)

        if result[:success]
          render json: {
            success: true,
            message: 'Order confirmed successfully',
            data: {
              order: order_serializer(@order.reload)
            }
          }
        else
          render json: {
            success: false,
            error: result[:error],
            details: result[:details]
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/cancel (Admin only)
      def cancel
        result = Orders::OrderCancellationService.cancel_order(@order, current_user, params[:reason])

        if result[:success]
          render json: {
            success: true,
            message: 'Order cancelled successfully',
            data: {
              order: order_serializer(@order.reload)
            }
          }
        else
          render json: {
            success: false,
            error: result[:error],
            details: result[:details]
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/ship (Admin only)
      def ship
        result = ship_order_with_service
        render_ship_response(result)
      end

      private

      def ship_order_with_service
        Orders::ShippingService.ship_order(
          @order,
          current_user,
          tracking_number: params[:tracking_number],
          carrier: params[:carrier]
        )
      end

      def render_ship_response(result)
        if result[:success]
          render json: {
            success: true,
            message: 'Order shipped successfully',
            data: { order: order_serializer(@order.reload) }
          }
        else
          render json: {
            success: false,
            error: result[:error],
            details: result[:details]
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/deliver (Admin only)
      def deliver
        result = deliver_order_with_service
        render_deliver_response(result)
      end

      def deliver_order_with_service
        Orders::DeliveryService.deliver_order(
          @order,
          current_user,
          delivery_notes: params[:delivery_notes],
          delivery_signature: params[:delivery_signature]
        )
      end

      def render_deliver_response(result)
        if result[:success]
          render json: {
            success: true,
            message: 'Order delivered successfully',
            data: { order: order_serializer(@order.reload) }
          }
        else
          render json: {
            success: false,
            error: result[:error],
            details: result[:details]
          }, status: :unprocessable_entity
        end
      end

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.expect(order: %i[customer_name customer_email customer_phone status])
      end

      def order_serializer(order)
        Orders::OrderSerializerService.serialize_order(order)
      end

      def order_item_serializer(item)
        Orders::OrderSerializerService.serialize_order_item(item)
      end

      # POST /api/v1/orders/:id/apply_discount
      def apply_discount
        discount_code = params[:discount_code]
        return render_error('Discount code is required', :unprocessable_entity) if discount_code.blank?

        result = @order.apply_discount(discount_code)

        if result[:success]
          render_success({
                           order: order_serializer(@order.reload),
                           discount: result[:discount],
                           discount_amount: result[:discount_amount]
                         }, 'Discount applied successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # DELETE /api/v1/orders/:id/remove_discount
      def remove_discount
        result = @order.remove_discount

        if result[:success]
          render_success({
                           order: order_serializer(@order.reload)
                         }, 'Discount removed successfully')
        else
          render_error('Failed to remove discount', :unprocessable_entity)
        end
      end
    end
  end
end
