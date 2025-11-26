# frozen_string_literal: true

module Api
  module V1
    class AddressesController < ApplicationController
      before_action :authenticate_user!

      # POST /api/v1/addresses/validate
      # Validate an address
      def validate
        result = Address::AddressValidationService.validate(address_params)

        if result[:success]
          render_success({
            valid: result[:valid],
            normalized_address: result[:normalized_address],
            errors: result[:errors] || [],
            suggestions: result[:suggestions] || []
          }, result[:valid] ? 'Address is valid' : 'Address validation failed')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # GET /api/v1/addresses/autocomplete
      # Get address autocomplete suggestions
      def autocomplete
        query = params[:query]
        country_code = params[:country_code]

        return render_error('Query is required', :bad_request) if query.blank?

        result = Address::AddressValidationService.autocomplete(query, country_code: country_code)

        if result[:success]
          render_success({
            suggestions: result[:suggestions] || []
          }, 'Address suggestions retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      private

      def address_params
        params.require(:address).permit(:street, :city, :state, :postal_code, :country_code, :country)
      end
    end
  end
end

