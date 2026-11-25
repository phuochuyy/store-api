# frozen_string_literal: true

module Auth
  class TokenValidationService
    class << self
      def authenticate(token)
        return { success: false, error: 'Token is blank' } if token.blank?

        result = Auth::Jwt::DecodeService.validate_token(token)
        return { success: false, error: result[:error] } unless result[:valid]

        { success: true, user: result[:user] }
      rescue StandardError => e
        Rails.logger.error "Token validation error: #{e.message}"
        { success: false, error: 'Authentication failed' }
      end

      # +resource+ may be a record or a model class (e.g. `ProductVariant` for :create).
      # Fails closed: a missing policy or an error inside a policy denies access.
      def authorize(user, resource, action)
        return { success: false, error: 'User not authenticated' } unless user

        policy_class = policy_class_for(resource)
        return { success: false, error: 'Authorization policy not found' } unless policy_class

        if policy_class.new(user, resource).public_send("#{action}?")
          { success: true }
        else
          { success: false, error: 'Access denied' }
        end
      rescue StandardError => e
        Rails.logger.error "Authorization error: #{e.class}: #{e.message}"
        { success: false, error: 'Authorization failed' }
      end

      private

      # Only a missing constant means "no policy". Rescuing NameError here would also swallow
      # NoMethodError (a NameError subclass) raised by bugs inside a policy.
      def policy_class_for(resource)
        model = resource.is_a?(Class) ? resource : resource.class
        "#{model.name}Policy".safe_constantize
      end
    end
  end
end
