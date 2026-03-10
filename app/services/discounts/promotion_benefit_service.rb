# frozen_string_literal: true

module Discounts
  class PromotionBenefitService
    class << self
      # Apply promotion benefit to order
      # @param order [Order] Order to apply benefit to
      # @param promotion [Promotion] Promotion to apply
      # @param benefit [Hash] Benefit details
      # @return [Hash] Result with success status
      def apply_promotion_benefit(order, promotion, benefit)
        ActiveRecord::Base.transaction do
          apply_discount_amount(order, benefit)
          add_free_items(order, benefit)
          handle_free_shipping(order, benefit)
          order.update_total_amount

          {
            success: true,
            benefit: benefit,
            promotion: PromotionSerializer.new(promotion).as_json
          }
        end
      rescue StandardError => e
        Rails.logger.error "Promotion benefit application error: #{e.message}"
        {
          success: false,
          error: 'Failed to apply promotion benefit',
          details: e.message
        }
      end

      # Calculate promotion benefit for order
      # @param order [Order] Order to calculate benefit for
      # @param promotion [Promotion] Promotion to calculate benefit for
      # @return [Hash] Calculated benefit details
      def calculate_promotion_benefit(order, promotion)
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'Promotion not found' } unless promotion

        case promotion.promotion_type
        when 'percentage_discount'
          calculate_percentage_discount(order, promotion)
        when 'fixed_discount'
          calculate_fixed_discount(order, promotion)
        when 'bulk_pricing'
          calculate_bulk_discount(order, promotion)
        when 'free_items'
          calculate_free_items(order, promotion)
        when 'free_shipping'
          calculate_free_shipping(order, promotion)
        else
          { success: false, error: "Unsupported promotion type: #{promotion.promotion_type}" }
        end
      end

      private

      def apply_discount_amount(order, benefit)
        return unless benefit[:discount_amount]&.positive?

        current_discount = order.discount_amount || 0
        new_discount = current_discount + benefit[:discount_amount]
        order.update!(discount_amount: new_discount)
      end

      def add_free_items(order, benefit)
        return if benefit[:free_items].blank?

        benefit[:free_items].each do |free_item|
          existing_item = order.order_items.find_by(product_id: free_item[:product_id])

          if existing_item
            existing_item.update!(quantity: existing_item.quantity + free_item[:quantity])
          else
            order.order_items.create!(
              product_id: free_item[:product_id],
              quantity: free_item[:quantity],
              unit_price: 0 # Free item
            )
          end
        end
      end

      def handle_free_shipping(order, benefit)
        return unless benefit[:free_shipping]

        Rails.logger.info "Free shipping applied to order #{order.id}"
        # This would be stored in order metadata or handled separately
      end

      def calculate_percentage_discount(order, promotion)
        discount_percentage = promotion.benefits['discount_percentage'] || 0
        applicable_items = get_applicable_items(order, promotion)
        subtotal = applicable_items.sum(&:total_price)
        discount_amount = (subtotal * discount_percentage / 100).round(2)

        {
          success: true,
          discount_amount: discount_amount,
          applicable_items: applicable_items.count,
          subtotal: subtotal
        }
      end

      def calculate_fixed_discount(order, promotion)
        discount_amount = promotion.benefits['discount_amount'] || 0
        applicable_items = get_applicable_items(order, promotion)
        subtotal = applicable_items.sum(&:total_price)
        actual_discount = [discount_amount, subtotal].min

        {
          success: true,
          discount_amount: actual_discount,
          applicable_items: applicable_items.count,
          subtotal: subtotal
        }
      end

      def calculate_bulk_discount(order, promotion)
        applicable_items = get_applicable_items(order, promotion)
        total_quantity = applicable_items.sum(&:quantity)
        bulk_pricing = promotion.benefits['bulk_pricing'] || []

        discount_amount = 0
        bulk_pricing.each do |tier|
          next unless total_quantity >= tier['min_quantity']

          discount_percentage = tier['discount_percentage'] || 0
          subtotal = applicable_items.sum(&:total_price)
          discount_amount = (subtotal * discount_percentage / 100).round(2)
        end

        {
          success: true,
          discount_amount: discount_amount,
          applicable_items: applicable_items.count,
          total_quantity: total_quantity
        }
      end

      def calculate_free_items(order, promotion)
        free_items = promotion.benefits['free_items'] || []
        applicable_items = get_applicable_items(order, promotion)

        calculated_free_items = free_items.map do |free_item|
          {
            product_id: free_item['product_id'],
            quantity: free_item['quantity'] || 1,
            product_name: Product.find(free_item['product_id']).name
          }
        end

        {
          success: true,
          free_items: calculated_free_items,
          applicable_items: applicable_items.count
        }
      end

      def calculate_free_shipping(order, promotion)
        applicable_items = get_applicable_items(order, promotion)
        subtotal = applicable_items.sum(&:total_price)
        minimum_amount = promotion.benefits['minimum_amount'] || 0

        free_shipping = subtotal >= minimum_amount

        {
          success: true,
          free_shipping: free_shipping,
          applicable_items: applicable_items.count,
          subtotal: subtotal,
          minimum_amount: minimum_amount
        }
      end

      def get_applicable_items(order, promotion)
        conditions = promotion.conditions || {}
        order_items = order.order_items.includes(:product)

        # Filter by product IDs if specified
        order_items = order_items.where(product_id: conditions['product_ids']) if conditions['product_ids'].present?

        # Filter by category IDs if specified
        if conditions['category_ids'].present?
          order_items = order_items.joins(:product)
                                   .where(products: { category_id: conditions['category_ids'] })
        end

        order_items
      end
    end
  end
end
