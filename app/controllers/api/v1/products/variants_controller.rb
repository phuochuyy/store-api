# frozen_string_literal: true

module Api
  module V1
    module Products
      class VariantsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_product
        before_action :set_variant, only: %i[show update destroy]

        # GET /api/v1/products/:product_id/variants
        def index
          variants = @product.product_variants.active.ordered
          render_success(variants.map { |v| variant_serializer(v) }, 'Variants retrieved successfully')
        end

        # GET /api/v1/products/:product_id/variants/:id
        def show
          render_success(variant_serializer(@variant), 'Variant retrieved successfully')
        end

        # POST /api/v1/products/:product_id/variants
        def create
          authorize! :create, ProductVariant

          variant = @product.product_variants.build(variant_params)
          if variant.save
            render_success(variant_serializer(variant), 'Variant created successfully', :created)
          else
            render_error('Failed to create variant', :unprocessable_entity, variant.errors.full_messages)
          end
        end

        # PATCH /api/v1/products/:product_id/variants/:id
        def update
          authorize! :update, @variant

          if @variant.update(variant_params)
            render_success(variant_serializer(@variant), 'Variant updated successfully')
          else
            render_error('Failed to update variant', :unprocessable_entity, @variant.errors.full_messages)
          end
        end

        # DELETE /api/v1/products/:product_id/variants/:id
        def destroy
          authorize! :destroy, @variant

          if @variant.destroy
            render_success(nil, 'Variant deleted successfully')
          else
            render_error('Failed to delete variant', :unprocessable_entity)
          end
        end

        private

        def set_product
          @product = Product.find(params[:product_id])
        rescue ActiveRecord::RecordNotFound
          render_error('Product not found', :not_found)
        end

        def set_variant
          @variant = @product.product_variants.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error('Variant not found', :not_found)
        end

        def variant_params
          params.require(:variant).permit(:name, :sku, :price, :stock_quantity, :is_active, :position,
                                          variant_options_attributes: %i[id option_type option_value _destroy])
        end

        def variant_serializer(variant)
          {
            id: variant.id,
            name: variant.name,
            sku: variant.sku,
            price: variant.price.to_f,
            stock_quantity: variant.stock_quantity,
            is_active: variant.is_active,
            in_stock: variant.in_stock?,
            display_name: variant.variant_display_name,
            options: variant.variant_options.map do |opt|
              {
                type: opt.option_type,
                value: opt.option_value
              }
            end
          }
        end
      end
    end
  end
end

