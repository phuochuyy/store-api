module Api
  module V1
    class BrandsController < Api::V1::BaseController
      before_action :set_brand, only: %i[show update destroy]
      before_action :authorize_brand, only: %i[create update destroy]

      def index
        pagination = extract_pagination
        result = Brands::BrandService.list_brands(pagination: pagination)

        render_success(result, 'Brands retrieved successfully')
      end

      def show
        result = Brands::BrandService.find_brand(@brand.id)
        render_success(result, 'Brand retrieved successfully')
      end

      def create
        validator = BrandValidator.new(brand_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_content, validator.errors.full_messages)
        end

        result = Brands::BrandService.create_brand(brand_params)

        if result[:success]
          render_success(result[:brand], 'Brand created successfully', :created)
        else
          render_error('Brand could not be created', :unprocessable_content, result[:errors])
        end
      end

      def update
        validator = BrandValidator.new(brand_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_content, validator.errors.full_messages)
        end

        result = Brands::BrandService.update_brand(@brand.id, brand_params)

        if result[:success]
          render_success(result[:brand], 'Brand updated successfully')
        else
          render_error('Brand could not be updated', :unprocessable_content, result[:errors])
        end
      end

      def destroy
        Brands::BrandService.delete_brand(@brand.id)
        render_success(nil, 'Brand deleted successfully')
      end

      private

      def set_brand
        @brand = Brand.find_by(id: params[:id])
        render_error('Brand not found', :not_found) unless @brand
      end

      def authorize_brand
        action = action_name.to_sym
        result = Auth::TokenValidationService.authorize(current_user, @brand || Brand.new, action)

        return if result[:success]

        render_error(result[:error], :forbidden)
      end

      def brand_params
        params.expect(brand: %i[name description])
      end

      def extract_pagination
        {
          page: params[:page],
          per_page: params[:per_page]
        }.compact
      end
    end
  end
end
