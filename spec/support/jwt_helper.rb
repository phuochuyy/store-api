# frozen_string_literal: true

module JwtHelper
  def generate_jwt_token(user, expires_in: 1.hour)
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: expires_in.from_now.to_i
    }
    JWT.encode(payload, secret_key, 'HS256')
  end

  def auth_headers(user)
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{generate_jwt_token(user)}"
    }
  end
end

RSpec.configure do |config|
  config.include JwtHelper
end
