require 'rails_helper'

# Revoking tokens issued by the real login endpoint. Those carry device_id and ip_hash and are
# longer than 255 characters, which is what broke revocation on MySQL: the raw token did not fit
# the old VARCHAR(255) column. JwtHelper tokens are shorter, so other specs never hit the limit.
RSpec.describe 'Token revocation', type: :request do
  let(:user) { create(:user) }
  # Clients commonly send a hashed device fingerprint; it ends up in both tokens.
  let(:headers) { { 'Content-Type' => 'application/json', 'X-Device-ID' => Digest::SHA256.hexdigest('iPhone') } }

  def login
    post '/api/v1/auth/login', params: { email: user.email, password: 'password123' }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    tokens = response.parsed_body['data'].slice('token', 'refresh_token')
    # Precondition: these specs are about tokens that do not fit in VARCHAR(255).
    expect(tokens.values.map(&:length)).to all(be > 255)
    tokens
  end

  def refresh(refresh_token)
    post '/api/v1/auth/refresh_token', params: { refresh_token: refresh_token }.to_json, headers: headers
  end

  def bearer(token) = headers.merge('Authorization' => "Bearer #{token}")

  shared_examples 'revocation' do
    it 'a refresh token cannot be used twice' do
      refresh_token = login['refresh_token']

      refresh(refresh_token)
      expect(response).to have_http_status(:ok)

      refresh(refresh_token)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'logout revokes the access token' do
      token = login['token']
      get '/api/v1/auth/me', headers: bearer(token)
      expect(response).to have_http_status(:ok)

      post '/api/v1/auth/logout', headers: bearer(token)
      expect(response).to have_http_status(:ok)

      get '/api/v1/auth/me', headers: bearer(token)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it_behaves_like 'revocation'

  # Without Redis there is no per-user logout timestamp and no cache: the database blacklist is
  # the only thing that revokes a token.
  context 'when Redis is down' do
    before do
      allow(Auth::Jwt::CacheService).to receive(:redis).and_raise(Redis::CannotConnectError, 'Redis is down')
    end

    it_behaves_like 'revocation'
  end
end
