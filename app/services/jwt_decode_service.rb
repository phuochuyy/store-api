# frozen_string_literal: true

class JwtDecodeService
  SECRET_KEY = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
  ALGORITHM = 'HS256'

  class << self
    # Decode and verify a JWT token
    # @param token [String] The JWT token to decode
    # @return [Hash] Decoded payload if valid, nil if invalid
    def decode(token)
      return nil if token.blank?

      decoded_token = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
      decoded_token.first
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    end

    # Decode and verify a JWT token, returning user if valid
    # @param token [String] The JWT token to decode
    # @return [User, nil] User object if token is valid, nil otherwise
    def decode_user(token)
      payload = decode(token)
      return nil unless payload

      user_id = payload['user_id']
      return nil unless user_id

      User.find_by(id: user_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    # Decode and verify a refresh token
    # @param token [String] The refresh token to decode
    # @return [Hash, nil] Decoded payload if valid, nil if invalid
    def decode_refresh_token(token)
      payload = decode(token)
      return nil unless payload
      return nil unless payload['type'] == 'refresh'

      payload
    end

    # Decode and verify a password reset token
    # @param token [String] The password reset token to decode
    # @return [Hash, nil] Decoded payload if valid, nil if invalid
    def decode_password_reset_token(token)
      payload = decode(token)
      return nil unless payload
      return nil unless payload['type'] == 'password_reset'

      payload
    end

    # Decode and verify an email verification token
    # @param token [String] The email verification token to decode
    # @return [Hash, nil] Decoded payload if valid, nil if invalid
    def decode_email_verification_token(token)
      payload = decode(token)
      return nil unless payload
      return nil unless payload['type'] == 'email_verification'

      payload
    end

    # Check if a token is expired
    # @param token [String] The JWT token to check
    # @return [Boolean] True if token is expired, false otherwise
    def expired?(token)
      payload = decode(token)
      return true unless payload

      exp = payload['exp']
      return true unless exp

      Time.current.to_i > exp
    end

    # Get token expiry time
    # @param token [String] The JWT token to check
    # @return [Time, nil] Expiry time if valid, nil otherwise
    def expiry_time(token)
      payload = decode(token)
      return nil unless payload

      exp = payload['exp']
      return nil unless exp

      Time.zone.at(exp)
    end

    # Get time until token expires
    # @param token [String] The JWT token to check
    # @return [ActiveSupport::Duration, nil] Time until expiry if valid, nil otherwise
    def time_until_expiry(token)
      exp_time = expiry_time(token)
      return nil unless exp_time

      exp_time - Time.current
    end

    # Validate token and return detailed result
    # @param token [String] The JWT token to validate
    # @return [Hash] Validation result with status and details
    def validate_token(token)
      return { valid: false, error: 'Token is blank' } if token.blank?

      payload = decode(token)
      return { valid: false, error: 'Invalid token format' } unless payload

      return { valid: false, error: 'Token has expired' } if expired?(token)

      user = User.find_by(id: payload['user_id'])
      return { valid: false, error: 'User not found' } unless user

      { valid: true, user: user, payload: payload }
    rescue StandardError => e
      { valid: false, error: e.message }
    end
  end
end
