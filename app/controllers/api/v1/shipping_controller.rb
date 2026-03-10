# frozen_string_literal: true

module Api
  module V1
    class ShippingController < Api::V1::BaseController
      before_action :admin_only!, only: %i[zones]

      # GET /api/v1/shipping/calculate
      # Calculate shipping cost for cart items
      def calculate
        cart = current_user.cart
        return render_error('Cart is empty', :bad_request) if cart.cart_items.empty?

        shipping_method_id = params[:shipping_method_id]
        country_code = params[:country_code] || params.dig(:address, :country_code)
        region = params[:region] || params.dig(:address, :region)

        return render_error('Shipping method is required', :bad_request) if shipping_method_id.blank?
        return render_error('Country code is required', :bad_request) if country_code.blank?

        # Convert cart items to order items format for calculation
        order_items = cart.cart_items.map do |cart_item|
          OpenStruct.new(
            product: cart_item.product,
            quantity: cart_item.quantity,
            unit_price: cart_item.product.price
          )
        end

        result = ::Shipping::ShippingCostCalculatorService.calculate(
          order_items,
          shipping_method_id: shipping_method_id,
          country_code: country_code,
          region: region
        )

        if result[:success]
          render_success({
                           shipping_cost: result[:shipping_cost],
                           base_cost: result[:base_cost],
                           free_shipping: result[:free_shipping],
                           shipping_method: {
                             id: result[:shipping_method].id,
                             name: result[:shipping_method].name,
                             estimated_days: result[:estimated_days]
                           },
                           weight: result[:weight]
                         }, 'Shipping cost calculated successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/shipping/methods
      # Get available shipping methods
      def methods
        methods = ShippingMethod.active.order(:name)
        render_success(methods.map { |m| shipping_method_serializer(m) }, 'Shipping methods retrieved successfully')
      end

      # GET /api/v1/shipping/zones
      # Get shipping zones (admin only)
      def zones
        zones = ShippingZone.all.order(:country_code, :region)
        render_success(zones.map { |z| shipping_zone_serializer(z) }, 'Shipping zones retrieved successfully')
      end

      private

      def shipping_method_serializer(method)
        {
          id: method.id,
          name: method.name,
          description: method.description,
          base_cost: method.base_cost.to_f,
          handling_fee: method.handling_fee.to_f,
          total_cost: method.total_base_cost.to_f,
          estimated_days: method.estimated_days
        }
      end

      def shipping_zone_serializer(zone)
        {
          id: zone.id,
          name: zone.name,
          country_code: zone.country_code,
          region: zone.region,
          base_cost: zone.base_cost.to_f,
          cost_per_kg: zone.cost_per_kg.to_f,
          free_shipping_threshold: zone.free_shipping_threshold&.to_f
        }
      end
    end
  end
end
