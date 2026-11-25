# frozen_string_literal: true

module Api
  module Authorization
    extend ActiveSupport::Concern

    # Raised on a denied check and rendered as 403. Raising (rather than rendering and
    # returning) stops the whole action, so authorize!/admin_only! are safe to call both
    # in a before_action and in the middle of an action body.
    class NotAuthorizedError < StandardError; end

    included do
      # Declared after ErrorHandling's catch-all StandardError handler, so it is matched first.
      rescue_from NotAuthorizedError, with: :render_forbidden
    end

    private

    # +resource+ may be a record (`@variant`) or a model class (`ProductVariant`, e.g. for create).
    def authorize!(action, resource)
      result = Auth::TokenValidationService.authorize(current_user, resource, action)
      raise NotAuthorizedError, result[:error] unless result[:success]
    end

    def admin_only!
      raise NotAuthorizedError, 'Admin access required' unless current_user&.admin?
    end

    def render_forbidden(exception)
      render_error(exception.message, :forbidden)
    end
  end
end
