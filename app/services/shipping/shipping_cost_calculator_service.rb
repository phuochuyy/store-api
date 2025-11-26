# frozen_string_literal: true

module Shipping
  class ShippingCostCalculatorService
    class << self
      # Calculate shipping cost for an order
      # @param order_items [Array<OrderItem>] Order items to calculate shipping for
      # @param shipping_method_id [Integer] Selected shipping method
      # @param country_code [String] Destination country code
      # @param region [String] Optional region/state
      # @return [Hash] Result with shipping cost and details
      def calculate(order_items, shipping_method_id:, country_code:, region: nil)
        return { success: false, error: 'Order items are required' } if order_items.blank?
        return { success: false, error: 'Shipping method is required' } if shipping_method_id.blank?
        return { success: false, error: 'Country code is required' } if country_code.blank?

        shipping_method = ShippingMethod.find_by(id: shipping_method_id, is_active: true)
        return { success: false, error: 'Shipping method not found' } unless shipping_method

        shipping_zone = find_shipping_zone(country_code, region)
        return { success: false, error: 'Shipping zone not found for this location' } unless shipping_zone

        # Calculate total weight
        total_weight = calculate_total_weight(order_items)

        # Calculate base cost
        base_cost = calculate_base_cost(shipping_method, shipping_zone, total_weight)

        # Check for free shipping threshold
        subtotal = order_items.sum { |item| item.unit_price * item.quantity }
        if shipping_zone.free_shipping_threshold.present? && subtotal >= shipping_zone.free_shipping_threshold
          return {
            success: true,
            shipping_cost: 0.0,
            base_cost: base_cost,
            free_shipping: true,
            shipping_method: shipping_method,
            estimated_days: shipping_method.estimated_days
          }
        end

        # Apply zone-method multiplier if exists
        zone_method = ShippingZoneMethod.find_by(
          shipping_zone: shipping_zone,
          shipping_method: shipping_method
        )
        final_cost = zone_method ? (base_cost * zone_method.cost_multiplier) : base_cost

        {
          success: true,
          shipping_cost: final_cost.round(2),
          base_cost: base_cost,
          free_shipping: false,
          shipping_method: shipping_method,
          estimated_days: shipping_method.estimated_days,
          weight: total_weight
        }
      rescue StandardError => e
        Rails.logger.error "Shipping cost calculation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        { success: false, error: 'Failed to calculate shipping cost', details: e.message }
      end

      private

      def find_shipping_zone(country_code, region = nil)
        # Try to find exact match first (country + region)
        if region.present?
          zone = ShippingZone.for_region(country_code, region).first
          return zone if zone
        end

        # Fallback to country-only match
        ShippingZone.for_country(country_code).where(region: nil).first ||
          ShippingZone.for_country(country_code).first
      end

      def calculate_total_weight(order_items)
        order_items.sum do |item|
          product = item.product
          weight = product.weight || 0.5 # Default 0.5kg if weight not set
          weight * item.quantity
        end
      end

      def calculate_base_cost(shipping_method, shipping_zone, total_weight)
        # Base cost from shipping method
        method_cost = shipping_method.total_base_cost

        # Zone base cost
        zone_base = shipping_zone.base_cost

        # Weight-based cost
        weight_cost = shipping_zone.cost_per_kg * total_weight

        method_cost + zone_base + weight_cost
      end
    end
  end
end
