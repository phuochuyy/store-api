# frozen_string_literal: true

module Tax
  class TaxCalculatorService
    class << self
      # Calculate tax for an order
      # @param order_items [Array<OrderItem>] Order items to calculate tax for
      # @param country_code [String] Destination country code
      # @param region [String] Optional region/state
      # @return [Hash] Result with tax amount and details
      def calculate(order_items, country_code:, region: nil)
        return { success: false, error: 'Order items are required' } if order_items.blank?
        return { success: false, error: 'Country code is required' } if country_code.blank?

        # Find applicable tax rates
        tax_rates = find_applicable_tax_rates(country_code, region, order_items)
        return { success: false, error: 'No tax rate found for this location' } if tax_rates.empty?

        # Calculate tax for each item
        total_tax = 0.0
        tax_breakdown = []

        order_items.each do |item|
          item_tax = calculate_item_tax(item, tax_rates)
          total_tax += item_tax[:tax_amount]
          tax_breakdown << item_tax if item_tax[:tax_amount].positive?
        end

        # Use the most specific tax rate for the order
        primary_tax_rate = tax_rates.first

        {
          success: true,
          tax_amount: total_tax.round(2),
          tax_rate: primary_tax_rate,
          tax_rate_value: primary_tax_rate.tax_rate,
          tax_breakdown: tax_breakdown
        }
      rescue StandardError => e
        Rails.logger.error "Tax calculation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        { success: false, error: 'Failed to calculate tax', details: e.message }
      end

      private

      def find_applicable_tax_rates(country_code, region, order_items)
        # Get all active tax rates for the country/region
        base_rates = TaxRate.active.for_country(country_code)
        rates = region.present? ? base_rates.for_region(country_code, region) : base_rates

        # For each item, find the most specific tax rate
        # Priority: category-specific > region-specific > general
        applicable_rates = []

        order_items.each do |item|
          category_id = item.product&.category_id

          # Try category-specific rate first
          category_rate = rates.for_category(category_id).first if category_id
          if category_rate
            applicable_rates << category_rate unless applicable_rates.include?(category_rate)
            next
          end

          # Try general rate
          general_rate = rates.general.first
          applicable_rates << general_rate if general_rate && !applicable_rates.include?(general_rate)
        end

        # Sort by specificity (category-specific first, then general)
        applicable_rates.sort_by { |rate| rate.category_id.nil? ? 1 : 0 }
      end

      def calculate_item_tax(item, tax_rates)
        product = item.product
        item_subtotal = item.unit_price * item.quantity

        # Find the most specific tax rate for this item
        tax_rate = tax_rates.find { |tr| tr.category_id == product.category_id } ||
                   tax_rates.find { |tr| tr.category_id.nil? } ||
                   tax_rates.first

        tax_amount = tax_rate.calculate_tax(item_subtotal)

        {
          order_item_id: item.id,
          product_id: product.id,
          tax_rate_id: tax_rate.id,
          tax_rate_value: tax_rate.tax_rate,
          tax_amount: tax_amount,
          subtotal: item_subtotal
        }
      end
    end
  end
end
