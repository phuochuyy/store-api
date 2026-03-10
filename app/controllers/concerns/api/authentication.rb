# frozen_string_literal: true

module Api
  # Authentication concern: before_action authenticate_user!, set @current_user from JWT (Authorization: Bearer).
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
    end

    private

    # Extract token from header, call TokenValidationService.authenticate; render 401 if missing/invalid; set @current_user.
    def authenticate_user!
      token = extract_token
      return render_error('Token missing', :unauthorized) unless token

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
