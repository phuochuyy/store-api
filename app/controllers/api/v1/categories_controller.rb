module Api
  module V1
    class CategoriesController < Api::V1::BaseController
      before_action :set_category, only: %i[show update destroy]
      before_action :admin_only!, only: %i[create update destroy]

      # GET /api/v1/categories
      def index
        @categories = Category.includes(:phones)
        @categories = @categories.page(params[:page]).per(params[:per_page] || 10)

        render json: {
          categories: @categories.map { |category| category_serializer(category) },
          pagination: {
            current_page: @categories.current_page,
            total_pages: @categories.total_pages,
            total_count: @categories.total_count,
            per_page: @categories.limit_value
          }
        }
      end

      # GET /api/v1/categories/:id
      def show
        render json: {
          category: category_serializer(@category),
          phones: @category.phones.limit(10).map { |phone| phone_serializer(phone) }
        }
      end

      # POST /api/v1/categories
      def create
        @category = Category.new(category_params)

        if @category.save
          render json: {
            message: 'Category created successfully',
            category: category_serializer(@category)
          }, status: :created
        else
          render json: {
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/categories/:id
      def update
        if @category.update(category_params)
          render json: {
            message: 'Category updated successfully',
            category: category_serializer(@category)
          }
        else
          render json: {
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/categories/:id
      def destroy
        @category.destroy
        render json: { message: 'Category deleted successfully' }
      end

      private

      def set_category
        @category = Category.find(params[:id])
      end

      def category_params
        params.expect(category: %i[name description])
      end

      def category_serializer(category)
        {
          id: category.id,
          name: category.name,
          description: category.description,
          phones_count: category.phones.count,
          created_at: category.created_at,
          updated_at: category.updated_at
        }
      end

      def phone_serializer(phone)
        {
          id: phone.id,
          name: phone.name,
          price: phone.price,
          stock_quantity: phone.stock_quantity
        }
      end
    end
  end
end
