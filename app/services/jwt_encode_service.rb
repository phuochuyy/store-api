# frozen_string_literal: true

class JWTEncodeService
  SECRET_KEY = Rails.application.credentials.secret_key_base || "fallback_secret_key"
  ALGORITHM = "HS256"
  DEFAULT_EXPIRY = 24.hours

  class << self
    # Encode a JWT token with user data
    # @param user [User] The user object to encode
    # @param expiry [ActiveSupport::Duration] Token expiry time (default: 24 hours)
    # @return [String] Encoded JWT token
    def encode(user, expiry: DEFAULT_EXPIRY)
      payload = {
        user_id: user.id,
        email: user.email,
        iat: Time.current.to_i,
        exp: (Time.current + expiry).to_i
      }

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Encode a refresh token
    # @param user [User] The user object to encode
    # @param expiry [ActiveSupport::Duration] Token expiry time (default: 7 days)
    # @return [String] Encoded refresh token
    def encode_refresh_token(user, expiry: 7.days)
      payload = {
        user_id: user.id,
        type: "refresh",
        iat: Time.current.to_i,
        exp: (Time.current + expiry).to_i
      }

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Encode a password reset token
    # @param user [User] The user object to encode
    # @param expiry [ActiveSupport::Duration] Token expiry time (default: 1 hour)
    # @return [String] Encoded password reset token
    def encode_password_reset_token(user, expiry: 1.hour)
      payload = {
        user_id: user.id,
        type: "password_reset",
        iat: Time.current.to_i,
        exp: (Time.current + expiry).to_i
      }

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Encode an email verification token
    # @param user [User] The user object to encode
    # @param expiry [ActiveSupport::Duration] Token expiry time (default: 24 hours)
    # @return [String] Encoded email verification token
    def encode_email_verification_token(user, expiry: 24.hours)
      payload = {
        user_id: user.id,
        email: user.email,
        type: "email_verification",
        iat: Time.current.to_i,
        exp: (Time.current + expiry).to_i
      }

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end
  end
end
