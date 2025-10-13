module Api
  module V1
    class DiscountsController < Api::V1::BaseController
      before_action :set_discount, only: %i[show update destroy stats]
      before_action :admin_only!, only: %i[create update destroy stats]

      # GET /api/v1/discounts
      def index
        filters = extract_filters
        pagination = extract_pagination

        result = Discounts::DiscountService.list_discounts(filters: filters, pagination: pagination)

        render_success(result, 'Discounts retrieved successfully')
      end

      # GET /api/v1/discounts/:id
      def show
        result = Discounts::DiscountService.find_discount(@discount.id)

        if result[:error]
          render_error(result[:error], :not_found)
        else
          render_success(result, 'Discount retrieved successfully')
        end
      end

      # POST /api/v1/discounts
      def create
        validator = DiscountValidator.new(discount_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Discounts::DiscountService.create_discount(discount_params)

        if result[:success]
          render_success(result[:discount], 'Discount created successfully', :created)
        else
          render_error('Discount could not be created', :unprocessable_entity, result[:errors])
        end
      end

      # PATCH/PUT /api/v1/discounts/:id
      def update
        validator = DiscountValidator.new(discount_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Discounts::DiscountService.update_discount(@discount, discount_params)

        if result[:success]
          render_success(result[:discount], 'Discount updated successfully')
        else
          render_error('Discount could not be updated', :unprocessable_entity, result[:errors])
        end
      end

      # DELETE /api/v1/discounts/:id
      def destroy
        result = Discounts::DiscountService.delete_discount(@discount)

        if result[:success]
          render_success(nil, 'Discount deleted successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/discounts/:id/stats
      def stats
        stats = Discounts::DiscountService.get_discount_stats(@discount)
        render_success(stats, 'Discount statistics retrieved successfully')
      end

      # POST /api/v1/discounts/:id/generate_codes
      def generate_codes
        quantity = params[:quantity]&.to_i || 1
        return render_error('Invalid quantity', :unprocessable_entity) if quantity <= 0 || quantity > 100

        result = Discounts::DiscountService.generate_discount_codes(@discount, quantity)

        if result[:success]
          render_success({ codes: result[:codes] }, "#{quantity} discount codes generated successfully")
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # POST /api/v1/discounts/validate
      def validate
        code = params[:code]
        order_amount = params[:order_amount]&.to_f || 0
        order_items = params[:order_items] || []

        return render_error('Discount code is required', :unprocessable_entity) if code.blank?

        result = Discounts::DiscountService.validate_discount_code(code, order_amount, order_items)

        if result[:valid]
          render_success(result, 'Discount code is valid')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      private

      def set_discount
        @discount = Discount.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Discount not found', :not_found)
      end

      def discount_params
        params.expect(
          discount: %i[name description discount_type value minimum_amount
                       maximum_discount usage_limit start_date end_date
                       is_active code applies_to applies_to_ids conditions]
        )
      end

      def extract_filters
        {
          discount_type: params[:discount_type],
          is_active: params[:is_active],
          search: params[:search],
          code: params[:code],
          date_from: params[:date_from],
          date_to: params[:date_to]
        }.compact
      end
    end
  end
end
