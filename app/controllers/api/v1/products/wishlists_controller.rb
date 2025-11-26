# frozen_string_literal: true

module Api
  module V1
    module Products
      class WishlistsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_wishlist, only: %i[show destroy]
        before_action :set_product, only: %i[create]

        def index
          @wishlists = current_user.product_wishlists.includes(:product)
          @wishlists = @wishlists.page(params[:page]).per(params[:per_page] || 20)

          data = {
            wishlists: @wishlists.map { |wishlist| wishlist_serializer(wishlist) },
            pagination: {
              current_page: @wishlists.current_page,
              total_pages: @wishlists.total_pages,
              total_count: @wishlists.total_count,
              per_page: @wishlists.limit_value
            }
          }

          render_success(data, 'Wishlist retrieved successfully')
        end

        def show
          render_success({ wishlist: wishlist_serializer(@wishlist) }, 'Wishlist item retrieved successfully')
        end

        def create
          return render_error('Product not found', :not_found) unless @product

          # Check if already in wishlist
          existing_wishlist = current_user.product_wishlists.find_by(product: @product)
          return render_error('Product already in wishlist', :unprocessable_content) if existing_wishlist

          @wishlist = current_user.product_wishlists.build(product: @product)

          if @wishlist.save
            render_success({ wishlist: wishlist_serializer(@wishlist) }, 'Product added to wishlist successfully',
                           :created)
          else
            render_error('Failed to add product to wishlist', :unprocessable_content, @wishlist.errors.full_messages)
          end
        end

        def destroy
          unless @wishlist.user == current_user
            return render_error('You can only remove your own wishlist items',
                                :forbidden)
          end

          @wishlist.destroy
          render_success(nil, 'Product removed from wishlist successfully')
        end

        def my_wishlist
          @wishlists = current_user.product_wishlists.includes(:product)
          @wishlists = @wishlists.page(params[:page]).per(params[:per_page] || 20)

          data = {
            wishlists: @wishlists.map { |wishlist| wishlist_serializer(wishlist) },
            total_count: current_user.product_wishlists.count
          }

          render_success(data, 'My wishlist retrieved successfully')
        end

        private

        def set_wishlist
          @wishlist = ProductWishlist.find_by(id: params[:id])
          render_error('Wishlist item not found', :not_found) unless @wishlist
        end

        def set_product
          @product = Product.find_by(id: params[:product_id])
        end

        def wishlist_serializer(wishlist)
          {
            id: wishlist.id,
            product: {
              id: wishlist.product.id,
              name: wishlist.product.name,
              price: wishlist.product.price,
              stock_quantity: wishlist.product.stock_quantity,
              image_url: wishlist.product.image.attached? ? url_for(wishlist.product.image) : nil
            },
            created_at: wishlist.created_at,
            updated_at: wishlist.updated_at
          }
        end
      end
    end
  end
end

