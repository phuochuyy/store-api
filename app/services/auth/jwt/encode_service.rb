# frozen_string_literal: true

require 'digest'

module Auth
  module Jwt
    class EncodeService
      class << self
        def encode(user, expiry: Config::ACCESS_TOKEN_EXPIRY, device_id: nil, ip_address: nil)
          payload = {
            user_id: user.id,
            email: user.email,
            iat: Time.current.to_i,
            exp: (Time.current + expiry).to_i
          }

          # Add device fingerprint for security
          payload[:device_id] = device_id if device_id.present?
          payload[:ip_hash] = Digest::SHA256.hexdigest(ip_address.to_s)[0..15] if ip_address.present?

          JWT.encode(payload, Config::SECRET_KEY, Config::ALGORITHM)
        end

        def encode_refresh_token(user, expiry: Config::REFRESH_TOKEN_EXPIRY, device_id: nil, ip_address: nil)
          payload = {
            user_id: user.id,
            type: 'refresh',
            iat: Time.current.to_i,
            exp: (Time.current + expiry).to_i
          }

          # Add device fingerprint for security
          payload[:device_id] = device_id if device_id.present?
          payload[:ip_hash] = Digest::SHA256.hexdigest(ip_address.to_s)[0..15] if ip_address.present?

          JWT.encode(payload, Config::SECRET_KEY, Config::ALGORITHM)
        end

        def encode_password_reset_token(user, expiry: 1.hour)
          payload = {
            user_id: user.id,
            type: 'password_reset',
            iat: Time.current.to_i,
            exp: (Time.current + expiry).to_i
          }

          JWT.encode(payload, Config::SECRET_KEY, Config::ALGORITHM)
        end

        def encode_email_verification_token(user, expiry: 24.hours)
          payload = {
            user_id: user.id,
            email: user.email,
            type: 'email_verification',
            iat: Time.current.to_i,
            exp: (Time.current + expiry).to_i
          }

          JWT.encode(payload, Config::SECRET_KEY, Config::ALGORITHM)
        end
      end
    end
  end
end
