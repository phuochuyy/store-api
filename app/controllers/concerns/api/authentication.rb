# frozen_string_literal: true

module Api
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
    end

    private

    def authenticate_user!
      token = extract_token
      return render_error('Token not provided', :unauthorized) unless token

      result = Auth::TokenValidationService.authenticate(token)
      return render_error(result[:error], :unauthorized) unless result[:success]

      @current_user = result[:user]
    end

    def current_user
      @current_user
    end

    def extract_token
      auth_header = request.headers['Authorization']
      return nil unless auth_header

      parts = auth_header.split
      return nil unless parts.length == 2
      return nil unless parts.first.downcase == 'bearer'

      parts.last
    end
  end
end
