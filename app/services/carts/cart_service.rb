module Carts
  class CartService
    class << self
      def get_or_create_cart(user: nil, session_id: nil)
        if user.present?
          cart = Cart.find_or_create_for_user(user)
        elsif session_id.present?
          cart = Cart.find_or_create_for_session(session_id)
        else
          raise ArgumentError, 'Either user or session_id must be provided'
        end

        {
          success: true,
          cart: cart,
          cart_items: cart.cart_items.includes(:product)
        }
      end

      def add_to_cart(cart, product_id, quantity = 1)
        product = Product.find(product_id)

        unless product.in_stock?
          return {
            success: false,
            error: 'Product is out of stock'
          }
        end

        if quantity > product.stock_quantity
          return {
            success: false,
            error: "Only #{product.stock_quantity} items available in stock"
          }
        end

        cart.add_product(product, quantity)

        {
          success: true,
          cart: cart.reload,
          cart_items: cart.cart_items.includes(:product),
          message: 'Product added to cart successfully'
        }
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          error: 'Product not found'
        }
      end

      def remove_from_cart(cart, product_id)
        product = Product.find(product_id)

        if cart.remove_product?(product)
          {
            success: true,
            cart: cart.reload,
            cart_items: cart.cart_items.includes(:product),
            message: 'Product removed from cart successfully'
          }
        else
          {
            success: false,
            error: 'Product not found in cart'
          }
        end
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          error: 'Product not found'
        }
      end

      def update_cart_item_quantity(cart, product_id, quantity)
        product = Product.find(product_id)

        unless product.in_stock?
          return {
            success: false,
            error: 'Product is out of stock'
          }
        end

        if quantity > product.stock_quantity
          return {
            success: false,
            error: "Only #{product.stock_quantity} items available in stock"
          }
        end

        if cart.update_product_quantity?(product, quantity)
          {
            success: true,
            cart: cart.reload,
            cart_items: cart.cart_items.includes(:product),
            message: 'Cart updated successfully'
          }
        else
          {
            success: false,
            error: 'Product not found in cart'
          }
        end
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          error: 'Product not found'
        }
      end

      def clear_cart(cart)
        cart.clear

        {
          success: true,
          cart: cart.reload,
          cart_items: [],
          message: 'Cart cleared successfully'
        }
      end

      def get_cart_details(cart)
        {
          success: true,
          cart: cart,
          cart_items: cart.cart_items.includes(:product),
          total_items: cart.total_items,
          total_amount: cart.total_amount
        }
      end

      def merge_carts(guest_cart, user_cart)
        return { success: true, cart: user_cart, cart_items: user_cart.cart_items.includes(:product), message: 'Carts merged successfully' } if guest_cart.empty?

        guest_cart.cart_items.includes(:product, :product_variant).each do |guest_item|
          existing_item = user_cart.cart_items.find_by(
            product_id: guest_item.product_id,
            product_variant_id: guest_item.product_variant_id
          )

          if existing_item
            new_quantity = existing_item.quantity + guest_item.quantity
            max_qty = guest_item.product_variant.present? ? guest_item.product_variant.stock_quantity : guest_item.product.stock_quantity
            new_quantity = max_qty if max_qty.present? && new_quantity > max_qty
            existing_item.update!(quantity: new_quantity)
          else
            if guest_item.product_variant_id.present?
              user_cart.cart_items.create!(
                product: guest_item.product,
                product_variant: guest_item.product_variant,
                quantity: guest_item.quantity,
                unit_price: guest_item.unit_price
              )
            else
              user_cart.add_product(guest_item.product, guest_item.quantity)
            end
          end
        end

        guest_cart.update!(status: 'abandoned')
        user_cart.calculate_total_amount

        {
          success: true,
          cart: user_cart.reload,
          cart_items: user_cart.cart_items.includes(:product),
          message: 'Carts merged successfully'
        }
      end

      def validate_cart_for_checkout(cart)
        errors = []

        if cart.empty?
          errors << 'Cart is empty'
          return { success: false, errors: errors }
        end

        cart.cart_items.each do |item|
          errors << "#{item.product.name} is out of stock" unless item.product.in_stock?

          if item.quantity > item.product.stock_quantity
            errors << "Only #{item.product.stock_quantity} #{item.product.name} available in stock"
          end
        end

        if errors.any?
          { success: false, errors: errors }
        else
          { success: true }
        end
      end
    end
  end
end
