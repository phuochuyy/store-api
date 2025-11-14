# frozen_string_literal: true

module Auth
  module Jwt
    class DecodeService
      class << self
        # Decode raw JWT token without blacklist check (internal use to avoid circular dependency)
        def decode_raw(token)
          return nil if token.blank?

          decoded_token = JWT.decode(token, Config::SECRET_KEY, true, { algorithm: Config::ALGORITHM })
          decoded_token.first
        rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
          Rails.logger.error "JWT decode error: #{e.message}"
          nil
        end

        def decode(token)
          return nil if token.blank?

          return nil if BlacklistService.blacklisted?(token)

          decode_raw(token)
        end

        def decode_user(token)
          payload = decode(token)
          return nil unless payload

          user_id = payload['user_id']
          return nil unless user_id

          # Try to get from cache first
          cached_user = CacheService.get_cached_user(user_id)
          return cached_user if cached_user

          # If not in cache, fetch from database
          user = User.find_by(id: user_id)
          # Cache the user if found
          CacheService.cache_user(user) if user

          user
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def decode_refresh_token(token)
          payload = decode(token)
          return nil unless payload
          return nil unless payload['type'] == 'refresh'

          payload
        end

        def decode_password_reset_token(token)
          payload = decode(token)
          return nil unless payload
          return nil unless payload['type'] == 'password_reset'

          payload
        end

        def decode_email_verification_token(token)
          payload = decode(token)
          return nil unless payload
          return nil unless payload['type'] == 'email_verification'

          payload
        end

        def expired?(token)
          payload = decode(token)
          return true unless payload

          exp = payload['exp']
          return true unless exp

          Time.current.to_i > exp
        end

        def expiry_time(token)
          payload = decode(token)
          return nil unless payload

          exp = payload['exp']
          return nil unless exp

          Time.zone.at(exp)
        end

        def time_until_expiry(token)
          exp_time = expiry_time(token)
          return nil unless exp_time

          exp_time - Time.current
        end

        def validate_token(token)
          return { valid: false, error: 'Token not provided' } if token.blank?

          # Check cached validation result first
          cached_result = CacheService.get_cached_validation(token)
          return cached_result if cached_result

          return { valid: false, error: 'Token has been revoked' } if BlacklistService.blacklisted?(token)

          payload = decode(token)
          return { valid: false, error: 'Invalid token' } unless payload

          return { valid: false, error: 'Token has expired' } if expired?(token)

          # Try to get user from cache first
          user_id = payload['user_id']
          user = CacheService.get_cached_user(user_id) || User.find_by(id: user_id)
          return { valid: false, error: 'User not found' } unless user

          # Cache the user if fetched from database
          CacheService.cache_user(user)

          result = { valid: true, user: user, payload: payload }
          # Cache successful validation
          CacheService.cache_validation(token, result)

          result
        rescue StandardError => e
          { valid: false, error: e.message }
        end
      end
    end
  end
end
