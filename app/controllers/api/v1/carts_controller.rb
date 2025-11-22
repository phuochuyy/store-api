module Api
  module V1
    class CartsController < Api::V1::BaseController
      before_action :set_cart, only: %i[show update destroy clear]

      def index
        result = Carts::CartService.get_or_create_cart(
          user: current_user,
          session_id: session_id
        )

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items],
                           total_items: result[:cart].total_items,
                           total_amount: result[:cart].total_amount
                         }, 'Cart retrieved successfully')
        else
          render_error(result[:error], :unprocessable_content)
        end
      end

      def show
        result = Carts::CartService.get_cart_details(@cart)

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items],
                           total_items: result[:total_items],
                           total_amount: result[:total_amount]
                         }, 'Cart details retrieved successfully')
        else
          render_error('Cart not found', :not_found)
        end
      end

      def create
        result = Carts::CartService.get_or_create_cart(
          user: current_user,
          session_id: session_id
        )

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, 'Cart created successfully', :created)
        else
          render_error(result[:error], :unprocessable_content)
        end
      end

      def update
        if @cart.update(cart_params)
          result = Carts::CartService.get_cart_details(@cart)
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, 'Cart updated successfully')
        else
          render_error('Cart update failed', :unprocessable_content, @cart.errors.full_messages)
        end
      end

      def destroy
        @cart.destroy
        render_success(nil, 'Cart deleted successfully')
      end

      def clear
        result = Carts::CartService.clear_cart(@cart)

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, result[:message])
        else
          render_error(result[:error], :unprocessable_content)
        end
      end

      def merge
        guest_session_id = params[:guest_session_id]

        return render_error('Guest session ID is required', :bad_request) if guest_session_id.blank?

        guest_cart = Cart.find_by(session_id: guest_session_id, status: 'active')
        user_cart = Cart.find_or_create_for_user(current_user)

        return render_error('Guest cart not found', :not_found) unless guest_cart

        result = Carts::CartService.merge_carts(guest_cart, user_cart)

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, result[:message])
        else
          render_error(result[:error], :unprocessable_content)
        end
      end

      private

      def set_cart
        @cart = if current_user
                  current_user.carts.find_by(id: params[:id])
                else
                  Cart.find_by(id: params[:id], session_id: session_id)
                end

        render_error('Cart not found', :not_found) unless @cart
      end

      def cart_params
        params.expect(cart: [:status])
      end

      def session_id
        request.headers['X-Session-ID'] || session.id
      end
    end
  end
end
