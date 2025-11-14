# frozen_string_literal: true

module Api
  module Authorization
    extend ActiveSupport::Concern

    private

    def authorize!(resource, action)
      result = Auth::TokenValidationService.authorize(current_user, resource, action)
      return if result[:success]

      render_error(result[:error], :forbidden)
    rescue StandardError => e
      Rails.logger.error "Authorization error: #{e.message}"
      render_error('Authorization failed', :forbidden)
    end

    def admin_only!
      return if current_user&.admin?

      render_error('Admin access required', :forbidden)
    end
  end
end
