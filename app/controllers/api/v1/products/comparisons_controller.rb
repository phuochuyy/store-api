# frozen_string_literal: true

module Api
  module V1
    module Products
      class ComparisonsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_comparison, only: %i[show update destroy]

        def index
          @comparisons = current_user.product_comparisons
          @comparisons = @comparisons.page(params[:page]).per(params[:per_page] || 10)

          data = {
            comparisons: @comparisons.map { |comparison| comparison_serializer(comparison) },
            pagination: {
              current_page: @comparisons.current_page,
              total_pages: @comparisons.total_pages,
              total_count: @comparisons.total_count,
              per_page: @comparisons.limit_value
            }
          }

          render_success(data, 'Product comparisons retrieved successfully')
        end

        def show
          render_success({ comparison: comparison_serializer(@comparison) }, 'Product comparison retrieved successfully')
        end

        def create
          product_ids = params[:product_ids] || []
          validation_result = validate_product_ids_for_comparison(product_ids)
          return validation_result if validation_result

          products = find_products_for_comparison(product_ids)
          return products unless products.is_a?(ActiveRecord::Relation)

          build_and_save_comparison(product_ids)
        end

        def validate_product_ids_for_comparison(product_ids)
          return render_error('At least 2 products are required for comparison', :bad_request) if product_ids.length < 2
          return render_error('Maximum 5 products can be compared', :bad_request) if product_ids.length > 5

          nil
        end

        def find_products_for_comparison(product_ids)
          products = Product.where(id: product_ids)
          return render_error('One or more products not found', :not_found) if products.count != product_ids.length

          products
        end

        def build_and_save_comparison(product_ids)
          @comparison = current_user.product_comparisons.build
          @comparison.product_ids_array = product_ids

          if @comparison.save
            render_success({ comparison: comparison_serializer(@comparison) },
                           'Product comparison created successfully', :created)
          else
            render_error('Failed to create product comparison', :unprocessable_content,
                         @comparison.errors.full_messages)
          end
        end

        def update
          authorization_result = authorize_comparison_update
          return authorization_result if authorization_result

          product_ids = params[:product_ids] || []
          validation_result = validate_product_ids_for_comparison(product_ids)
          return validation_result if validation_result

          products = find_products_for_comparison(product_ids)
          return products unless products.is_a?(ActiveRecord::Relation)

          update_comparison_products(product_ids)
        end

        def authorize_comparison_update
          return nil if @comparison.user == current_user

          render_error('You can only update your own comparisons', :forbidden)
        end

        def update_comparison_products(product_ids)
          @comparison.product_ids_array = product_ids
          if @comparison.save
            render_success({ comparison: comparison_serializer(@comparison) },
                           'Product comparison updated successfully')
          else
            render_error('Failed to update product comparison', :unprocessable_content,
                         @comparison.errors.full_messages)
          end
        end

        def destroy
          unless @comparison.user == current_user
            return render_error('You can only delete your own comparisons',
                                :forbidden)
          end

          @comparison.destroy
          render_success(nil, 'Product comparison deleted successfully')
        end

        def my_comparisons
          @comparisons = current_user.product_comparisons

          data = {
            comparisons: @comparisons.map { |comparison| comparison_serializer(comparison) },
            total_count: @comparisons.count
          }

          render_success(data, 'My product comparisons retrieved successfully')
        end

        private

        def set_comparison
          @comparison = ProductComparison.find_by(id: params[:id])
          render_error('Product comparison not found', :not_found) unless @comparison
        end

        def comparison_serializer(comparison)
          product_ids = comparison.product_ids_array
          products = Product.where(id: product_ids)

          {
            id: comparison.id,
            products: serialize_comparison_products(products),
            created_at: comparison.created_at,
            updated_at: comparison.updated_at
          }
        end

        def serialize_comparison_products(products)
          products.map { |product| serialize_comparison_product(product) }
        end

        def serialize_comparison_product(product)
          {
            id: product.id,
            name: product.name,
            description: product.description,
            price: product.price,
            stock_quantity: product.stock_quantity,
            brand: serialize_product_brand(product.brand),
            category: serialize_product_category(product.category),
            image_url: product.image.attached? ? url_for(product.image) : nil
          }
        end

        def serialize_product_brand(brand)
          return nil unless brand

          { id: brand.id, name: brand.name }
        end

        def serialize_product_category(category)
          return nil unless category

          { id: category.id, name: category.name }
        end
      end
    end
  end
end

