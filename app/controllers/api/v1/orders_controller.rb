module Api
  module V1
    class OrdersController < Api::V1::BaseController
      before_action :set_order, only: %i[show update destroy confirm cancel ship deliver apply_discount remove_discount]
      before_action :admin_only!, only: %i[index update destroy confirm cancel ship deliver]

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
        @order = Order.new(order_params)

        if @order.save
          # Add order items from params
          if params[:order_items].present?
            params[:order_items].each do |item_params|
              product = Product.find(item_params[:product_id])
              @order.order_items.create!(
                product: product,
                quantity: item_params[:quantity].to_i,
                unit_price: product.price
              )
              product.reduce_stock(item_params[:quantity].to_i)
            end
            @order.update_total_amount
          end

          render json: {
            message: 'Order created successfully',
            order: order_serializer(@order)
          }, status: :created
        else
          render json: {
            errors: @order.errors.full_messages
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
        result = Orders::ShippingService.ship_order(
          @order,
          current_user,
          tracking_number: params[:tracking_number],
          carrier: params[:carrier]
        )

        if result[:success]
          render json: {
            success: true,
            message: 'Order shipped successfully',
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

      # POST /api/v1/orders/:id/deliver (Admin only)
      def deliver
        result = Orders::DeliveryService.deliver_order(
          @order,
          current_user,
          delivery_notes: params[:delivery_notes],
          delivery_signature: params[:delivery_signature]
        )

        if result[:success]
          render json: {
            success: true,
            message: 'Order delivered successfully',
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

      private

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.expect(order: %i[customer_name customer_email customer_phone status])
      end

      def order_serializer(order)
        {
          id: order.id,
          customer_name: order.customer_name,
          customer_email: order.customer_email,
          customer_phone: order.customer_phone,
          total_amount: order.total_amount,
          status: order.status,
          tracking_number: order.tracking_number,
          carrier: order.carrier,
          shipped_at: order.shipped_at,
          delivered_at: order.delivered_at,
          delivery_notes: order.delivery_notes,
          delivery_signature: order.delivery_signature,
          shipping_status: order.shipping_status,
          estimated_delivery_date: order.estimated_delivery_date,
          created_at: order.created_at,
          updated_at: order.updated_at
        }
      end

      def order_item_serializer(item)
        {
          id: item.id,
          product: {
            id: item.product.id,
            name: item.product.name,
            price: item.product.price
          },
          quantity: item.quantity,
          unit_price: item.unit_price,
          total_price: item.total_price
        }
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
