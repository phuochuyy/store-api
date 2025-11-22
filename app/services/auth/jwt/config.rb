# frozen_string_literal: true

module Auth
  module Jwt
    module Config
      SECRET_KEY = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
      ALGORITHM = 'HS256'

      # Access token expires in 30 minutes (shorter for better security)
      ACCESS_TOKEN_EXPIRY = 30.minutes

      # Refresh token expires in 7 days
      REFRESH_TOKEN_EXPIRY = 7.days

      # Default expiry (for backward compatibility, use ACCESS_TOKEN_EXPIRY)
      DEFAULT_EXPIRY = ACCESS_TOKEN_EXPIRY
    end
  end
end
