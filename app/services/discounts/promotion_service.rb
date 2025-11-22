module Discounts
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  class PromotionService
    class << self
      def create_promotion(params)
        promotion = Promotion.new(params)

        if promotion.save
          { success: true, promotion: promotion }
        else
          { success: false, errors: promotion.errors.full_messages }
        end
      end

      def update_promotion(promotion, params)
        if promotion.update(params)
          { success: true, promotion: promotion }
        else
          { success: false, errors: promotion.errors.full_messages }
        end
      end

      def delete_promotion(promotion)
        promotion.destroy
        { success: true }
      end

      # List promotions with filters and pagination
      def list_promotions(filters: {}, pagination: {})
        promotions = Promotion.all
        promotions = apply_filters(promotions, filters)
        promotions = paginate(promotions, pagination)

        {
          promotions: promotions.map { |promotion| PromotionSerializer.new(promotion).as_json },
          pagination: pagination_meta(promotions)
        }
      end

      # Find promotion by ID
      def find_promotion(id)
        promotion = Promotion.find(id)
        { promotion: PromotionSerializer.new(promotion).as_json }
      rescue ActiveRecord::RecordNotFound
        { error: 'Promotion not found' }
      end

      def get_applicable_promotions(order)
        applicable_promotions = []

        Promotion.available.order(priority: :desc).each do |promotion|
          next unless promotion.applies_to_order?(order)

          benefit = promotion.calculate_benefit(order)
          applicable_promotions << {
            promotion: PromotionSerializer.new(promotion).as_json,
            benefit: benefit
          }
        end

        { promotions: applicable_promotions }
      end

      # Apply promotion to order
      def apply_promotion_to_order(order, promotion_id)
        promotion = Promotion.find(promotion_id)
        return { success: false, error: 'Promotion not found' } unless promotion
        return { success: false, error: 'Promotion not available' } unless promotion.available?

        unless promotion.applies_to_order?(order)
          return { success: false, error: 'Promotion does not apply to this order' }
        end

        benefit = promotion.calculate_benefit(order)
        if benefit[:discount_amount].zero? && benefit[:free_items].empty? && !benefit[:free_shipping]
          return { success: false,
                   error: 'No benefit from this promotion' }
        end

        # Apply the promotion benefit
        result = apply_promotion_benefit(order, promotion, benefit)

        promotion.increment_usage! if result[:success]

        result
      end

      def get_promotion_stats(promotion)
        {
          total_usage: promotion.used_count,
          remaining_usage: promotion.usage_limit ? promotion.usage_limit - promotion.used_count : 'Unlimited',
          is_active: promotion.is_active?,
          is_current: promotion.current?,
          days_remaining: promotion.end_date ? (promotion.end_date - Time.current).to_i / 1.day : nil
        }
      end

      # Bulk create promotions
      def bulk_create_promotions(promotions_data)
        results = { created: 0, failed: 0, errors: [] }

        promotions_data.each do |promotion_data|
          result = create_promotion(promotion_data)
          if result[:success]
            results[:created] += 1
          else
            results[:failed] += 1
            results[:errors] << result[:errors]
          end
        end

        results
      end

      private

      def apply_filters(promotions, filters)
        promotions = promotions.where(promotion_type: filters[:promotion_type]) if filters[:promotion_type].present?
        promotions = promotions.where(is_active: filters[:is_active]) if filters[:is_active].present?
        promotions = promotions.where(priority: filters[:priority]) if filters[:priority].present?
        promotions = promotions.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?

        promotions = promotions.where(created_at: (filters[:date_from])..) if filters[:date_from].present?

        promotions = promotions.where(created_at: ..(filters[:date_to])) if filters[:date_to].present?

        promotions
      end

      def paginate(promotions, pagination)
        page = pagination[:page] || 1
        per_page = pagination[:per_page] || 10

        promotions.page(page).per(per_page)
      end

      def pagination_meta(promotions)
        {
          current_page: promotions.current_page,
          total_pages: promotions.total_pages,
          total_count: promotions.total_count,
          per_page: promotions.limit_value
        }
      end

      def apply_promotion_benefit(order, promotion, benefit)
        PromotionBenefitService.apply_promotion_benefit(order, promotion, benefit)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
