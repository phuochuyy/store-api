module Api
  module V1
    class PromotionsController < Api::V1::BaseController
      before_action :set_promotion, only: %i[show update destroy stats]
      before_action :admin_only!, only: %i[create update destroy stats]

      # GET /api/v1/promotions
      def index
        filters = extract_filters
        pagination = extract_pagination

        result = Discounts::PromotionService.list_promotions(filters: filters, pagination: pagination)

        render_success(result, 'Promotions retrieved successfully')
      end

      # GET /api/v1/promotions/:id
      def show
        result = Discounts::PromotionService.find_promotion(@promotion.id)

        if result[:error]
          render_error(result[:error], :not_found)
        else
          render_success(result, 'Promotion retrieved successfully')
        end
      end

      # POST /api/v1/promotions
      def create
        validator = PromotionValidator.new(promotion_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Discounts::PromotionService.create_promotion(promotion_params)

        if result[:success]
          render_success(result[:promotion], 'Promotion created successfully', :created)
        else
          render_error('Promotion could not be created', :unprocessable_entity, result[:errors])
        end
      end

      # PATCH/PUT /api/v1/promotions/:id
      def update
        validator = PromotionValidator.new(promotion_params)

        unless validator.valid?
          return render_error('Validation failed', :unprocessable_entity, validator.errors.full_messages)
        end

        result = Discounts::PromotionService.update_promotion(@promotion, promotion_params)

        if result[:success]
          render_success(result[:promotion], 'Promotion updated successfully')
        else
          render_error('Promotion could not be updated', :unprocessable_entity, result[:errors])
        end
      end

      # DELETE /api/v1/promotions/:id
      def destroy
        result = Discounts::PromotionService.delete_promotion(@promotion)

        if result[:success]
          render_success(nil, 'Promotion deleted successfully')
        else
          render_error('Failed to delete promotion', :unprocessable_entity)
        end
      end

      # GET /api/v1/promotions/:id/stats
      def stats
        stats = Discounts::PromotionService.get_promotion_stats(@promotion)
        render_success(stats, 'Promotion statistics retrieved successfully')
      end

      # GET /api/v1/promotions/applicable
      def applicable
        order_id = params[:order_id]
        return render_error('Order ID is required', :unprocessable_entity) if order_id.blank?

        order = Order.find(order_id)
        result = Discounts::PromotionService.get_applicable_promotions(order)

        render_success(result, 'Applicable promotions retrieved successfully')
      rescue ActiveRecord::RecordNotFound
        render_error('Order not found', :not_found)
      end

      # POST /api/v1/promotions/:id/apply
      def apply
        order_id = params[:order_id]
        return render_error('Order ID is required', :unprocessable_entity) if order_id.blank?

        order = Order.find(order_id)
        result = Discounts::PromotionService.apply_promotion_to_order(order, @promotion.id)

        if result[:success]
          render_success(result, 'Promotion applied successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      rescue ActiveRecord::RecordNotFound
        render_error('Order not found', :not_found)
      end

      private

      def set_promotion
        @promotion = Promotion.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Promotion not found', :not_found)
      end

      def promotion_params
        params.expect(
          promotion: %i[name description promotion_type conditions benefits
                        start_date end_date is_active usage_limit priority stackable]
        )
      end

      def extract_filters
        {
          promotion_type: params[:promotion_type],
          is_active: params[:is_active],
          priority: params[:priority],
          search: params[:search],
          date_from: params[:date_from],
          date_to: params[:date_to]
        }.compact
      end
    end
  end
end
