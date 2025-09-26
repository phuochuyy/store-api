module Api
  module V1
    class OrdersController < Api::V1::BaseController
      before_action :set_order, only: %i[show update destroy]
      before_action :admin_only!, only: %i[index update destroy]

      # GET /api/v1/orders (Admin only)
      def index
        @orders = Order.includes(:order_items, :phones).recent
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
              phone = Phone.find(item_params[:phone_id])
              @order.order_items.create!(
                phone: phone,
                quantity: item_params[:quantity].to_i,
                unit_price: phone.price
              )
              phone.reduce_stock(item_params[:quantity].to_i)
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
          created_at: order.created_at,
          updated_at: order.updated_at
        }
      end

      def order_item_serializer(item)
        {
          id: item.id,
          phone: {
            id: item.phone.id,
            name: item.phone.name,
            price: item.phone.price
          },
          quantity: item.quantity,
          unit_price: item.unit_price,
          total_price: item.total_price
        }
      end
    end
  end
end
