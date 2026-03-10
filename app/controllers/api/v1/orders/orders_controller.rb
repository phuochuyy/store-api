# frozen_string_literal: true

module Api
  module V1
    module Orders
      class OrdersController < Api::V1::BaseController
      before_action :set_order, only: %i[show update destroy confirm cancel ship deliver apply_discount remove_discount]
      before_action :admin_only!, only: %i[update destroy confirm cancel ship deliver]
      before_action :ensure_order_owner_or_admin!, only: %i[show apply_discount remove_discount]
      skip_before_action :authenticate_user!, only: [:track]

      def index
        # Admin: all orders. Customer: only their orders (e-commerce standard)
        base = current_user.admin? ? Order : current_user.orders
        @orders = base.includes(:order_items, :products).recent
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

      def show
        render json: {
          order: order_serializer(@order),
          order_items: @order.order_items.map { |item| order_item_serializer(item) }
        }
      end

      def create
        attrs = order_params.to_h.symbolize_keys
        attrs[:user_id] = current_user&.id if current_user
        result = ::Orders::OrderCreationService.create_order(attrs, params[:order_items])

        if result[:success]
          render json: {
            message: result[:message],
            order: order_serializer(result[:order])
          }, status: :created
        else
          render json: {
            errors: result[:details]
          }, status: :unprocessable_content
        end
      end

      def update
        if @order.update(order_params)
          render json: {
            message: 'Order updated successfully',
            order: order_serializer(@order)
          }
        else
          render json: {
            errors: @order.errors.full_messages
          }, status: :unprocessable_content
        end
      end

      def destroy
        @order.destroy
        render json: { message: 'Order deleted successfully' }
      end

      def confirm
        result = ::Orders::OrderConfirmationService.confirm_order(@order, current_user)

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
          }, status: :unprocessable_content
        end
      end

      def cancel
        result = ::Orders::OrderCancellationService.cancel_order(@order, current_user, params[:reason])

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
          }, status: :unprocessable_content
        end
      end

      def ship
        result = ship_order_with_service
        render_ship_response(result)
      end

      def deliver
        result = deliver_order_with_service
        render_deliver_response(result)
      end

      # Public order tracking (no authentication required)
      def track
        tracking_number = params[:tracking_number]
        return render_error('Tracking number is required', :bad_request) if tracking_number.blank?

        @order = Order.find_by(tracking_number: tracking_number)
        return render_error('Order not found', :not_found) unless @order

        order_data = {
          id: @order.id,
          status: @order.status,
          tracking_number: @order.tracking_number,
          carrier: @order.carrier,
          shipped_at: @order.shipped_at&.iso8601,
          delivered_at: @order.delivered_at&.iso8601,
          shipping_status: @order.shipping_status,
          tracking_info: @order.tracking_info,
          delivery_info: @order.delivery_info
        }

        # Add estimated_delivery_date if method exists
        if @order.respond_to?(:estimated_delivery_date) && @order.estimated_delivery_date
          order_data[:estimated_delivery_date] = @order.estimated_delivery_date.iso8601
        end

        render_success({ order: order_data }, 'Order tracking information retrieved successfully')
      end

      def apply_discount
        discount_code = params[:discount_code]
        return render_error('Discount code is required', :unprocessable_content) if discount_code.blank?

        result = @order.apply_discount(discount_code)

        if result[:success]
          render_success({
                           order: order_serializer(@order.reload),
                           discount: result[:discount],
                           discount_amount: result[:discount_amount]
                         }, 'Discount applied successfully')
        else
          render_error(result[:error], :unprocessable_content)
        end
      end

      def remove_discount
        result = @order.remove_discount

        if result[:success]
          render_success({
                           order: order_serializer(@order.reload)
                         }, 'Discount removed successfully')
        else
          render_error('Failed to remove discount', :unprocessable_content)
        end
      end

      private

      def ensure_order_owner_or_admin!
        return if current_user&.admin?
        return render_error('Order not found', :not_found) if @order.user_id != current_user&.id
      end

      def ship_order_with_service
        ::Orders::ShippingService.ship_order(
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
          }, status: :unprocessable_content
        end
      end

      def deliver_order_with_service
        ::Orders::DeliveryService.deliver_order(
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
          }, status: :unprocessable_content
        end
      end

      def set_order
        @order = Order.find_by(id: params[:id])
        return render_error('Order not found', :not_found) unless @order
      end

      def order_params
        params.expect(order: %i[customer_name customer_email customer_phone status])
      end

      def order_serializer(order)
        ::Orders::OrderSerializerService.serialize_order(order)
      end

      def order_item_serializer(item)
        ::Orders::OrderSerializerService.serialize_order_item(item)
      end
      end
    end
  end
end
