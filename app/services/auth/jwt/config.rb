# frozen_string_literal: true

module Auth
  module Jwt
    module Config
      # Fail closed: sign with a dedicated JWT_SECRET_KEY, or else the app's secret_key_base.
      # Rails.application.secret_key_base raises at boot in production when no secret is
      # configured, instead of silently signing tokens with a string anyone can read.
      SECRET_KEY = ENV['JWT_SECRET_KEY'].presence || Rails.application.secret_key_base
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
