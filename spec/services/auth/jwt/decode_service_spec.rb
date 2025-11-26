require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Auth::Jwt::DecodeService, type: :service do
  let(:user) { create(:user, email: 'test@example.com', role: 'admin') }

  describe '.decode' do
    context 'with valid token' do
      let(:valid_token) do
        payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: Time.current.to_i,
          exp: 1.hour.from_now.to_i
        }
        JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
      end

      it 'decodes token successfully' do
        result = described_class.decode(valid_token)

        expect(result).to be_present
        expect(result['user_id']).to eq(user.id)
        expect(result['email']).to eq(user.email)
        expect(result['role']).to eq(user.role)
      end

      it 'returns payload with all expected fields' do
        result = described_class.decode(valid_token)

        expect(result).to include(
          'user_id' => user.id,
          'email' => user.email,
          'role' => user.role,
          'iat' => be_present,
          'exp' => be_present
        )
      end
    end

    context 'with invalid token' do
      it 'returns nil for malformed token' do
        result = described_class.decode('invalid-token')
        expect(result).to be_nil
      end

      it 'returns nil for token with wrong secret' do
        wrong_secret_token = JWT.encode({ user_id: user.id }, 'wrong-secret')
        result = described_class.decode(wrong_secret_token)
        expect(result).to be_nil
      end

      it 'returns nil for expired token' do
        expired_payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: 2.days.ago.to_i,
          exp: 1.day.ago.to_i
        }
        expired_token = JWT.encode(expired_payload, Rails.application.credentials.secret_key_base, 'HS256')

        result = described_class.decode(expired_token)
        expect(result).to be_nil
      end

      it 'returns nil for token with invalid algorithm' do
        invalid_algo_token = JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base, 'HS512')
        result = described_class.decode(invalid_algo_token)
        expect(result).to be_nil
      end

      it 'returns nil for token issued before user logout' do
        # Create token issued 1 hour ago
        old_payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: 1.hour.ago.to_i,
          exp: 1.hour.from_now.to_i
        }
        old_token = JWT.encode(old_payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

        # Set logout timestamp to 30 minutes ago (after token was issued)
        logout_time = 30.minutes.ago
        Auth::Jwt::CacheService.set_user_logout_timestamp(user.id)
        # Manually set the timestamp to 30 minutes ago for testing
        timestamp_key = Auth::Jwt::CacheService.user_logout_timestamp_key(user.id)
        Auth::Jwt::CacheService.redis.setex(timestamp_key, 7.days.to_i, logout_time.to_i.to_s)

        result = described_class.decode(old_token)
        expect(result).to be_nil
      end

      it 'returns payload for token issued after user logout' do
        # Set logout timestamp first
        logout_time = 1.hour.ago
        begin
          timestamp_key = "jwt:auth:logout_timestamp:#{user.id}"
          Auth::Jwt::CacheService.redis.setex(timestamp_key, 7.days.to_i, logout_time.to_i.to_s)
        rescue StandardError
          skip 'Redis not available for logout timestamp test'
        end

        # Create token issued after logout
        new_payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: 30.minutes.ago.to_i,
          exp: 1.hour.from_now.to_i
        }
        new_token = JWT.encode(new_payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

        result = described_class.decode(new_token)
        expect(result).to be_present
        expect(result['user_id']).to eq(user.id)
      end
    end

    context 'with nil or empty token' do
      it 'returns nil for nil token' do
        result = described_class.decode(nil)
        expect(result).to be_nil
      end

      it 'returns nil for empty token' do
        result = described_class.decode('')
        expect(result).to be_nil
      end

      it 'returns nil for whitespace token' do
        result = described_class.decode('   ')
        expect(result).to be_nil
      end
    end
  end

  describe '.decode_refresh_token' do
    let(:refresh_token) do
      payload = {
        user_id: user.id,
        type: 'refresh',
        iat: Time.current.to_i,
        exp: 7.days.from_now.to_i
      }
      JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
    end

    it 'returns payload for valid refresh token' do
      result = described_class.decode_refresh_token(refresh_token)
      expect(result).to be_present
      expect(result['type']).to eq('refresh')
      expect(result['user_id']).to eq(user.id)
    end

    it 'returns nil for non-refresh token' do
      payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: Time.current.to_i,
        exp: 1.hour.from_now.to_i
      }
      token = JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')

      result = described_class.decode_refresh_token(token)
      expect(result).to be_nil
    end
  end

  describe '.decode_user' do
    let(:token) { Auth::Jwt::EncodeService.encode(user) }

    context 'with valid token' do
      it 'returns user from cache if available' do
        # Cache the user first
        Auth::Jwt::CacheService.cache_user(user)

        result = described_class.decode_user(token)

        expect(result).to be_a(User)
        expect(result.id).to eq(user.id)
      end

      it 'fetches user from database if not cached' do
        result = described_class.decode_user(token)

        expect(result).to be_a(User)
        expect(result.id).to eq(user.id)
        # User should now be cached
        expect(Auth::Jwt::CacheService.get_cached_user(user.id)).to be_present
      end

      it 'returns user for valid token' do
        result = described_class.decode_user(token)
        expect(result).to eq(user)
      end
    end

    context 'with invalid token' do
      it 'returns nil for invalid token' do
        result = described_class.decode_user('invalid-token')
        expect(result).to be_nil
      end

      it 'returns nil for blacklisted token' do
        Auth::Jwt::BlacklistService.blacklist_token(token)

        result = described_class.decode_user(token)

        expect(result).to be_nil
      end

      it 'returns nil for non-existent user' do
        payload = {
          user_id: 99_999,
          email: 'nonexistent@example.com',
          role: 'customer',
          iat: Time.current.to_i,
          exp: 1.hour.from_now.to_i
        }
        token = JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

        result = described_class.decode_user(token)
        expect(result).to be_nil
      end
    end
  end

  describe '.validate_token' do
    let(:valid_token) do
      payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: Time.current.to_i,
        exp: 1.hour.from_now.to_i
      }
      JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
    end

    it 'returns valid result for valid token' do
      result = described_class.validate_token(valid_token)

      expect(result[:valid]).to be true
      expect(result[:user]).to eq(user)
      expect(result[:payload]).to be_present
    end

    it 'uses cached validation result if available' do
      # First validation should cache the result
      result1 = described_class.validate_token(valid_token)
      expect(result1[:valid]).to be true

      # Second validation should use cache
      cached_result = Auth::Jwt::CacheService.get_cached_validation(valid_token)
      expect(cached_result).to be_present
      expect(cached_result[:valid]).to be true
    end

    it 'caches user after validation' do
      described_class.validate_token(valid_token)

      cached_user = Auth::Jwt::CacheService.get_cached_user(user.id)
      expect(cached_user).to be_present
      expect(cached_user.id).to eq(user.id)
    end

    it 'returns invalid result for blank token' do
      result = described_class.validate_token('')

      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Token not provided')
    end

    it 'returns invalid result for expired token' do
      expired_payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: 2.days.ago.to_i,
        exp: 1.day.ago.to_i
      }
      expired_token = JWT.encode(expired_payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

      result = described_class.validate_token(expired_token)

      expect(result[:valid]).to be false
      expect(result[:error]).to be_present
    end

    it 'returns invalid result for token issued before user logout' do
      # Create token issued 1 hour ago
      old_payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: 1.hour.ago.to_i,
        exp: 1.hour.from_now.to_i
      }
      old_token = JWT.encode(old_payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

      # Set logout timestamp to 30 minutes ago (after token was issued)
      logout_time = 30.minutes.ago
      # Manually set the timestamp for testing
      begin
        timestamp_key = "jwt:auth:logout_timestamp:#{user.id}"
        Auth::Jwt::CacheService.redis.setex(timestamp_key, 7.days.to_i, logout_time.to_i.to_s)
      rescue StandardError
        skip 'Redis not available for logout timestamp test'
      end

      result = described_class.validate_token(old_token)

      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Token has been revoked (user logged out)')
    end

    it 'returns valid result for token issued after user logout' do
      # Set logout timestamp first
      logout_time = 1.hour.ago
      # Manually set the timestamp for testing
      begin
        timestamp_key = "jwt:auth:logout_timestamp:#{user.id}"
        Auth::Jwt::CacheService.redis.setex(timestamp_key, 7.days.to_i, logout_time.to_i.to_s)
      rescue StandardError
        skip 'Redis not available for logout timestamp test'
      end

      # Create token issued after logout
      new_payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: 30.minutes.ago.to_i,
        exp: 1.hour.from_now.to_i
      }
      new_token = JWT.encode(new_payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

      result = described_class.validate_token(new_token)

      expect(result[:valid]).to be true
      expect(result[:user]).to eq(user)
    end
  end

  describe '.expired?' do
    let(:valid_token) do
      payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: Time.current.to_i,
        exp: 1.hour.from_now.to_i
      }
      JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
    end

    it 'returns false for valid token' do
      result = described_class.expired?(valid_token)
      expect(result).to be false
    end

    it 'returns true for expired token' do
      expired_payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        iat: 2.days.ago.to_i,
        exp: 1.day.ago.to_i
      }
      expired_token = JWT.encode(expired_payload, Rails.application.credentials.secret_key_base, 'HS256')

      result = described_class.expired?(expired_token)
      expect(result).to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
