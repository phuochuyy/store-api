module Api
  module V1
    class CartItemsController < Api::V1::BaseController
      before_action :set_cart
      before_action :set_cart_item, only: %i[show update destroy]

      # GET /api/v1/carts/:cart_id/cart_items
      def index
        cart_items = @cart.cart_items.includes(:product)

        render_success({
                         cart_items: cart_items,
                         total_items: @cart.total_items,
                         total_amount: @cart.total_amount
                       }, 'Cart items retrieved successfully')
      end

      # GET /api/v1/carts/:cart_id/cart_items/:id
      def show
        render_success({
                         cart_item: @cart_item,
                         product: @cart_item.product
                       }, 'Cart item retrieved successfully')
      end

      # POST /api/v1/carts/:cart_id/cart_items
      def create
        result = Carts::CartService.add_to_cart(
          @cart,
          cart_item_params[:product_id],
          cart_item_params[:quantity] || 1
        )

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, result[:message], :created)
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # PUT /api/v1/carts/:cart_id/cart_items/:id
      def update
        result = Carts::CartService.update_cart_item_quantity(
          @cart,
          @cart_item.product_id,
          cart_item_params[:quantity]
        )

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, result[:message])
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # DELETE /api/v1/carts/:cart_id/cart_items/:id
      def destroy
        result = Carts::CartService.remove_from_cart(
          @cart,
          @cart_item.product_id
        )

        if result[:success]
          render_success({
                           cart: result[:cart],
                           cart_items: result[:cart_items]
                         }, result[:message])
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      private

      def set_cart
        @cart = if current_user
                  current_user.carts.find(params[:cart_id])
                else
                  Cart.find_by(id: params[:cart_id], session_id: session_id)
                end

        render_error('Cart not found', :not_found) unless @cart
      end

      def set_cart_item
        @cart_item = @cart.cart_items.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Cart item not found', :not_found)
      end

      def cart_item_params
        params.require(:cart_item).permit(:product_id, :quantity)
      end

      def session_id
        request.headers['X-Session-ID'] || session.id
      end
    end
  end
end
