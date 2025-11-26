# frozen_string_literal: true

module Api
  module V1
    class TaxController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/tax/calculate
      # Calculate tax for cart items
      def calculate
        cart = current_user.cart
        return render_error('Cart is empty', :bad_request) if cart.cart_items.empty?

        country_code = params[:country_code] || params.dig(:address, :country_code)
        region = params[:region] || params.dig(:address, :region)

        return render_error('Country code is required', :bad_request) if country_code.blank?

        # Convert cart items to order items format for calculation
        order_items = cart.cart_items.map do |cart_item|
          OpenStruct.new(
            product: cart_item.product,
            quantity: cart_item.quantity,
            unit_price: cart_item.product.price
          )
        end

        result = Tax::TaxCalculatorService.calculate(
          order_items,
          country_code: country_code,
          region: region
        )

        if result[:success]
          render_success({
                           tax_amount: result[:tax_amount],
                           tax_rate: {
                             id: result[:tax_rate].id,
                             name: result[:tax_rate].name,
                             rate: result[:tax_rate_value],
                             type: result[:tax_rate].tax_type
                           },
                           tax_breakdown: result[:tax_breakdown]
                         }, 'Tax calculated successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/tax/rates
      # Get tax rates (admin only)
      def rates
        authorize! :read, TaxRate
        country_code = params[:country_code]
        region = params[:region]

        rates = TaxRate.active
        rates = rates.for_country(country_code) if country_code.present?
        rates = rates.for_region(country_code, region) if country_code.present? && region.present?

        render_success(rates.map { |r| tax_rate_serializer(r) }, 'Tax rates retrieved successfully')
      end

      private

      def tax_rate_serializer(rate)
        {
          id: rate.id,
          name: rate.name,
          country_code: rate.country_code,
          region: rate.region,
          category_id: rate.category_id,
          tax_rate: rate.tax_rate.to_f,
          tax_type: rate.tax_type
        }
      end
    end
  end
end
