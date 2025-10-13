module Api
  module V1
    class CategoriesController < Api::V1::BaseController
      before_action :set_category, only: %i[show update destroy]

      # GET /api/v1/categories
      def index
        @categories = Category.includes(:products)
        @categories = @categories.page(params[:page]).per(params[:per_page] || 10)

        data = {
          categories: @categories.map { |category| category_serializer(category) },
          pagination: {
            current_page: @categories.current_page,
            total_pages: @categories.total_pages,
            total_count: @categories.total_count,
            per_page: @categories.limit_value
          }
        }

        render_success(data, 'Categories retrieved successfully')
      end

      # GET /api/v1/categories/:id
      def show
        data = {
          category: category_serializer(@category),
          products: @category.products.limit(10).map { |product| product_serializer(product) }
        }

        render_success(data, 'Category retrieved successfully')
      end

      # POST /api/v1/categories
      def create
        return unless ensure_admin!

        @category = Category.new(category_params)

        if @category.save
          data = { category: category_serializer(@category) }
          render_success(data, 'Category created successfully', :created)
        else
          render_error('Category could not be created', :unprocessable_entity, @category.errors.full_messages)
        end
      end

      # PATCH/PUT /api/v1/categories/:id
      def update
        return unless ensure_admin!

        if @category.update(category_params)
          data = { category: category_serializer(@category) }
          render_success(data, 'Category updated successfully')
        else
          render_error('Category could not be updated', :unprocessable_entity, @category.errors.full_messages)
        end
      end

      # DELETE /api/v1/categories/:id
      def destroy
        return unless ensure_admin!

        @category.destroy
        render_success(nil, 'Category deleted successfully')
      end

      private

      def ensure_admin!
        return if current_user&.admin?

        render_error('Admin access required', :forbidden)
        false
      end

      def set_category
        @category = Category.find_by(id: params[:id])
        render_error('Category not found', :not_found) unless @category
      end

      def category_params
        params.expect(category: %i[name description])
      end

      def category_serializer(category)
        {
          id: category.id,
          name: category.name,
          description: category.description,
          products_count: category.products.count,
          created_at: category.created_at,
          updated_at: category.updated_at
        }
      end

      def product_serializer(product)
        {
          id: product.id,
          name: product.name,
          price: product.price,
          stock_quantity: product.stock_quantity
        }
      end
    end
  end
end
