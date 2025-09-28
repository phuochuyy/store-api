module Api
  module V1
    class ProductsController < Api::V1::BaseController
      before_action :set_product, only: %i[show update destroy upload_image remove_image]
      before_action :authorize_product, only: %i[create update destroy upload_image remove_image]

      # GET /api/v1/products
      def index
        filters = extract_filters
        pagination = extract_pagination

        result = Products::ProductService.list_products(filters: filters, pagination: pagination)

        render_success(result, 'Products retrieved successfully')
      end

      # GET /api/v1/products/:id
      def show
        result = Products::ProductService.find_product(@product.id)
        render_success(result, 'Product retrieved successfully')
      end

      # POST /api/v1/products
      def create
        validator = ProductValidator.new(product_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Products::ProductService.create_product(product_params)

        if result[:success]
          render_success(result, 'Product created successfully', :created)
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # PUT /api/v1/products/:id
      def update
        validator = ProductValidator.new(product_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Products::ProductService.update_product(@product.id, product_params)

        if result[:success]
          render_success(result, 'Product updated successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # DELETE /api/v1/products/:id
      def destroy
        result = Products::ProductService.delete_product(@product.id)

        if result[:success]
          render_success({}, 'Product deleted successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # POST /api/v1/products/:id/upload_image
      def upload_image
        if @product.image.attached?
          return render_error('Product already has an image. Remove existing image first.', :unprocessable_entity)
        end

        @product.image.attach(params[:image])
        render_success({}, 'Image uploaded successfully')
      end

      # DELETE /api/v1/products/:id/remove_image
      def remove_image
        return render_error('Product has no image to remove.', :unprocessable_entity) unless @product.image.attached?

        @product.image.purge
        render_success({}, 'Image removed successfully')
      end

      private

      def set_product
        @product = Product.find_by(id: params[:id])
        render_error('Product not found', :not_found) unless @product
      end

      def authorize_product
        authorize @product || Product.new, policy_class: ProductPolicy
      end

      def product_params
        params.require(:product).permit(:name, :description, :price, :stock_quantity, :brand_id, :category_id,
                                        :specifications)
      end

      def extract_filters
        {
          search: params[:search],
          brand_id: params[:brand_id],
          category_id: params[:category_id],
          min_price: params[:min_price],
          max_price: params[:max_price],
          in_stock: params[:in_stock]
        }.compact
      end

      def extract_pagination
        {
          page: params[:page] || 1,
          per_page: params[:per_page] || 10
        }
      end
    end
  end
end
