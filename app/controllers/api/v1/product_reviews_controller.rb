# frozen_string_literal: true

module Api
  module V1
    class ProductReviewsController < Api::V1::BaseController
      before_action :set_product, only: %i[index create]
      before_action :set_review, only: %i[show update destroy helpful]
      before_action :authenticate_user!, only: %i[create update destroy helpful]

      def index
        @reviews = if @product
                     @product.product_reviews.includes(:user).approved.recent
                   else
                     ProductReview.includes(:user, :product).approved.recent
                   end

        @reviews = @reviews.page(params[:page]).per(params[:per_page] || 10)

        data = {
          reviews: @reviews.map { |review| review_serializer(review) },
          pagination: {
            current_page: @reviews.current_page,
            total_pages: @reviews.total_pages,
            total_count: @reviews.total_count,
            per_page: @reviews.limit_value
          }
        }

        render_success(data, 'Reviews retrieved successfully')
      end

      def show
        render_success({ review: review_serializer(@review) }, 'Review retrieved successfully')
      end

      def create
        return render_error('Product not found', :not_found) unless @product

        # Check if user already reviewed this product
        existing_review = @product.product_reviews.find_by(user: current_user)
        if existing_review
          return render_error('You have already reviewed this product', :unprocessable_content)
        end

        @review = @product.product_reviews.build(review_params)
        @review.user = current_user
        @review.status = 'pending' # Admin approval required

        if @review.save
          render_success({ review: review_serializer(@review) }, 'Review created successfully. Pending admin approval.', :created)
        else
          render_error('Review could not be created', :unprocessable_content, @review.errors.full_messages)
        end
      end

      def update
        return render_error('You can only update your own reviews', :forbidden) unless @review.user == current_user

        if @review.update(review_params)
          @review.update(status: 'pending') # Re-approval required after update
          render_success({ review: review_serializer(@review) }, 'Review updated successfully. Pending admin approval.')
        else
          render_error('Review could not be updated', :unprocessable_content, @review.errors.full_messages)
        end
      end

      def destroy
        return render_error('You can only delete your own reviews', :forbidden) unless @review.user == current_user || current_user.admin?

        @review.destroy
        render_success(nil, 'Review deleted successfully')
      end

      def helpful
        # Toggle helpful vote
        if @review.helpful_count.nil?
          @review.update(helpful_count: 1)
          message = 'Marked as helpful'
        else
          @review.update(helpful_count: @review.helpful_count + 1)
          message = 'Marked as helpful'
        end

        render_success({ review: review_serializer(@review.reload) }, message)
      end

      private

      def set_product
        @product = Product.find_by(id: params[:product_id]) if params[:product_id].present?
      end

      def set_review
        @review = ProductReview.find_by(id: params[:id])
        render_error('Review not found', :not_found) unless @review
      end

      def review_params
        params.expect(review: %i[rating title content verified_purchase])
      end

      def review_serializer(review)
        {
          id: review.id,
          user: {
            id: review.user.id,
            name: review.user.name,
            email: review.user.email
          },
          product: review.product ? {
            id: review.product.id,
            name: review.product.name
          } : nil,
          rating: review.rating,
          title: review.title,
          content: review.content,
          status: review.status,
          verified_purchase: review.verified_purchase || false,
          helpful_count: review.helpful_count || 0,
          created_at: review.created_at,
          updated_at: review.updated_at
        }
      end
    end
  end
end

