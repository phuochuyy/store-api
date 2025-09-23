class Auth::AuthenticationService
  class << self
    def authenticate(token)
      return { success: false, error: "Token is blank" } if token.blank?

      result = JwtDecodeService.validate_token(token)
      return { success: false, error: result[:error] } unless result[:valid]

      { success: true, user: result[:user] }
    rescue StandardError => e
      Rails.logger.error "Authentication error: #{e.message}"
      { success: false, error: "Authentication failed" }
    end

    def authorize(user, resource, action)
      return { success: false, error: "User not authenticated" } unless user
      
      policy_class = "#{resource.class.name}Policy".constantize
      policy = policy_class.new(user, resource)
      
      if policy.public_send("#{action}?")
        { success: true }
      else
        { success: false, error: "Access denied" }
      end
    rescue NameError
      { success: false, error: "Authorization policy not found" }
    rescue StandardError => e
      Rails.logger.error "Authorization error: #{e.message}"
      { success: false, error: "Authorization failed" }
    end
  end
end
