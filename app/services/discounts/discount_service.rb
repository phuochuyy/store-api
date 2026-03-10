module Discounts
  class DiscountService
    class << self
      def create_discount(params)
        discount = Discount.new(params)

        if discount.save
          { success: true, discount: discount }
        else
          { success: false, errors: discount.errors.full_messages }
        end
      end

      def update_discount(discount, params)
        if discount.update(params)
          { success: true, discount: discount }
        else
          { success: false, errors: discount.errors.full_messages }
        end
      end

      def delete_discount(discount)
        if discount.orders.exists?
          { success: false, error: 'Cannot delete discount with existing orders' }
        else
          discount.destroy
          { success: true }
        end
      end

      # List discounts with filters and pagination
      def list_discounts(filters: {}, pagination: {})
        discounts = Discount.all
        discounts = apply_filters(discounts, filters)
        discounts = paginate(discounts, pagination)

        {
          discounts: discounts.map { |discount| DiscountSerializer.new(discount).as_json },
          pagination: pagination_meta(discounts)
        }
      end

      # Find discount by ID
      def find_discount(id)
        discount = Discount.find(id)
        { discount: DiscountSerializer.new(discount).as_json }
      rescue ActiveRecord::RecordNotFound
        { error: 'Discount not found' }
      end

      def validate_discount_code(code, order_amount = 0, order_items = [])
        discount = Discount.available.find_by(code: code.upcase)
        return { valid: false, error: 'Invalid discount code' } unless discount

        # Check minimum amount
        unless discount.meets_minimum_amount?(order_amount)
          return {
            valid: false,
            error: "Minimum order amount of $#{discount.minimum_amount} required"
          }
        end

        unless discount.applies_to_items?(order_items)
          return { valid: false, error: 'Discount does not apply to items in your order' }
        end

        # Calculate discount amount
        discount_amount = discount.calculate_discount(order_amount)
        return { valid: false, error: 'No discount applicable' } if discount_amount <= 0

        {
          valid: true,
          discount: DiscountSerializer.new(discount).as_json,
          discount_amount: discount_amount,
          final_amount: order_amount - discount_amount
        }
      end

      # Generate discount codes
      def generate_discount_codes(discount, quantity)
        codes = []

        quantity.times do
          coupon = discount.coupons.create!(
            code: generate_unique_coupon_code,
            user: nil,
            order: nil
          )
          codes << coupon.code
        end

        { success: true, codes: codes }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      def get_discount_stats(discount)
        {
          total_usage: discount.used_count,
          remaining_usage: discount.usage_limit ? discount.usage_limit - discount.used_count : 'Unlimited',
          total_orders: discount.orders.count,
          total_discount_given: discount.orders.sum(:discount_amount),
          average_discount: discount.orders.average(:discount_amount),
          recent_usage: discount.orders.recent.limit(10).pluck(:created_at, :discount_amount)
        }
      end

      # Bulk create discounts
      def bulk_create_discounts(discounts_data)
        results = { created: 0, failed: 0, errors: [] }

        discounts_data.each do |discount_data|
          result = create_discount(discount_data)
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

      def apply_filters(discounts, filters)
        discounts = discounts.where(discount_type: filters[:discount_type]) if filters[:discount_type].present?
        discounts = discounts.where(is_active: filters[:is_active]) if filters[:is_active].present?
        discounts = discounts.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?
        discounts = discounts.where('code ILIKE ?', "%#{filters[:code]}%") if filters[:code].present?

        discounts = discounts.where(created_at: (filters[:date_from])..) if filters[:date_from].present?

        discounts = discounts.where(created_at: ..(filters[:date_to])) if filters[:date_to].present?

        discounts
      end

      def paginate(discounts, pagination)
        page = pagination[:page] || 1
        per_page = pagination[:per_page] || 10

        discounts.page(page).per(per_page)
      end

      def pagination_meta(discounts)
        {
          current_page: discounts.current_page,
          total_pages: discounts.total_pages,
          total_count: discounts.total_count,
          per_page: discounts.limit_value
        }
      end

      def generate_unique_coupon_code
        loop do
          code = "COUPON#{SecureRandom.hex(6).upcase}"
          break code unless Coupon.exists?(code: code)
        end
      end
    end
  end
end
