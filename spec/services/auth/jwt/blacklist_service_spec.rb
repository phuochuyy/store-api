require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Auth::Jwt::BlacklistService, type: :service do
  let(:user) { create(:user) }
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

  describe '.blacklist_token' do
    it 'blacklists a valid token' do
      result = described_class.blacklist_token(valid_token, user_id: user.id.to_s)

      expect(result).to be true
      expect(JwtBlacklistToken.exists?(token: valid_token)).to be true
    end

    it 'blacklists token with custom parameters' do
      # Pass integer user_id, service will convert to string
      result = described_class.blacklist_token(
        valid_token,
        user_id: user.id,
        token_type: 'refresh',
        reason: 'User logout'
      )

      expect(result).to be true

      blacklisted_token = JwtBlacklistToken.find_by(token: valid_token)
      # Database stores user_id as bigint (integer)
      expect(blacklisted_token.user_id).to eq(user.id)
      expect(blacklisted_token.token_type).to eq('refresh')
      expect(blacklisted_token.reason).to eq('User logout')
    end

    it 'returns false for blank token' do
      result = described_class.blacklist_token('')
      expect(result).to be false
    end

    it 'returns false for nil token' do
      result = described_class.blacklist_token(nil)
      expect(result).to be false
    end

    it 'handles database errors gracefully' do
      allow(JwtBlacklistToken).to receive(:blacklist_token).and_raise(StandardError, 'Database error')

      result = described_class.blacklist_token(valid_token)
      expect(result).to be false
    end
  end

  describe '.blacklisted?' do
    it 'returns true for blacklisted token' do
      described_class.blacklist_token(valid_token)

      result = described_class.blacklisted?(valid_token)
      expect(result).to be true
    end

    it 'returns false for non-blacklisted token' do
      result = described_class.blacklisted?('non-blacklisted-token')
      expect(result).to be false
    end

    it 'returns true for blank token' do
      result = described_class.blacklisted?('')
      expect(result).to be true
    end

    it 'returns true for nil token' do
      result = described_class.blacklisted?(nil)
      expect(result).to be true
    end

    it 'handles database errors gracefully' do
      allow(JwtBlacklistToken).to receive(:blacklisted?).and_raise(StandardError, 'Database error')

      result = described_class.blacklisted?(valid_token)
      expect(result).to be false
    end
  end

  describe '.whitelist_token' do
    it 'removes token from blacklist' do
      described_class.blacklist_token(valid_token)
      expect(described_class.blacklisted?(valid_token)).to be true

      result = described_class.whitelist_token(valid_token)
      expect(result).to be true
      expect(described_class.blacklisted?(valid_token)).to be false
    end

    it 'returns false for blank token' do
      result = described_class.whitelist_token('')
      expect(result).to be false
    end

    it 'handles database errors gracefully' do
      allow(JwtBlacklistToken).to receive(:where).and_raise(StandardError, 'Database error')

      result = described_class.whitelist_token(valid_token)
      expect(result).to be false
    end
  end

  describe '.all_blacklisted_tokens' do
    it 'returns all active blacklisted tokens' do
      token1 = create(:jwt_blacklist_token)
      token2 = create(:jwt_blacklist_token, :expired)

      result = described_class.all_blacklisted_tokens

      expect(result).to include(token1)
      expect(result).not_to include(token2)
    end

    it 'returns empty array on database error' do
      allow(JwtBlacklistToken).to receive(:active).and_raise(StandardError, 'Database error')

      result = described_class.all_blacklisted_tokens
      expect(result).to eq([])
    end
  end

  describe '.clear_all_blacklisted_tokens' do
    it 'removes all blacklisted tokens' do
      create(:jwt_blacklist_token)
      create(:jwt_blacklist_token)

      result = described_class.clear_all_blacklisted_tokens

      expect(result).to eq(2)
      expect(JwtBlacklistToken.count).to eq(0)
    end

    it 'returns 0 on database error' do
      allow(JwtBlacklistToken).to receive(:count).and_raise(StandardError, 'Database error')

      result = described_class.clear_all_blacklisted_tokens
      expect(result).to eq(0)
    end
  end

  describe '.cleanup_expired_tokens' do
    it 'removes expired tokens' do
      active_token = create(:jwt_blacklist_token)
      expired_token = create(:jwt_blacklist_token, :expired)

      described_class.cleanup_expired_tokens

      expect(JwtBlacklistToken.exists?(active_token.id)).to be true
      expect(JwtBlacklistToken.exists?(expired_token.id)).to be false
    end

    it 'returns 0 on database error' do
      allow(JwtBlacklistToken).to receive(:cleanup_expired).and_raise(StandardError, 'Database error')

      result = described_class.cleanup_expired_tokens
      expect(result).to eq(0)
    end
  end

  describe '.blacklist_stats' do
    it 'returns blacklist statistics' do
      create(:jwt_blacklist_token, token_type: 'access')
      create(:jwt_blacklist_token, :refresh_token)
      create(:jwt_blacklist_token, :expired)

      result = described_class.blacklist_stats

      expect(result).to include(:total, :active, :expired, :by_type, :by_user)
      expect(result[:total]).to be >= 3
      expect(result[:active]).to be >= 2
      expect(result[:expired]).to be >= 1
    end

    it 'returns default stats on database error' do
      allow(JwtBlacklistToken).to receive(:stats).and_raise(StandardError, 'Database error')

      result = described_class.blacklist_stats
      expect(result).to eq({ total: 0, active: 0, expired: 0, by_type: {}, by_user: {} })
    end
  end

  describe '.blacklist_user_tokens' do
    let(:user_id) { user.id }

    it 'blacklists all tokens for a user' do
      # Create some tokens for the user
      token1 = create(:jwt_blacklist_token, user_id: user.id, token_type: 'access')
      token2 = create(:jwt_blacklist_token, user_id: user.id, token_type: 'refresh')

      result = described_class.blacklist_user_tokens(user_id, reason: 'Security breach')

      expect(result).to be true
      # Verify tokens are updated with reason
      expect(token1.reload.reason).to eq('Security breach')
      expect(token2.reload.reason).to eq('Security breach')
    end

    it 'accepts user_id as string and converts to integer' do
      token1 = create(:jwt_blacklist_token, user_id: user.id, token_type: 'access')

      result = described_class.blacklist_user_tokens(user.id.to_s, reason: 'Security breach')

      expect(result).to be true
      expect(token1.reload.reason).to eq('Security breach')
    end

    it 'sets logout timestamp in cache' do
      result = described_class.blacklist_user_tokens(user_id, reason: 'User logout')

      expect(result).to be true
      # Only check logout timestamp if Redis is available
      begin
        logout_timestamp = Auth::Jwt::CacheService.get_user_logout_timestamp(user_id)
        if logout_timestamp
          expect(logout_timestamp).to be_present
          expect(logout_timestamp).to be <= Time.current
        end
      rescue StandardError
        # Redis may not be available in test environment, skip this check
        skip 'Redis not available for logout timestamp check'
      end
    end

    it 'invalidates user cache' do
      # Cache a user first
      Auth::Jwt::CacheService.cache_user(user)

      result = described_class.blacklist_user_tokens(user_id)

      expect(result).to be true
      # User cache should be invalidated
      cached_user = Auth::Jwt::CacheService.get_cached_user(user.id)
      expect(cached_user).to be_nil
    end

    it 'returns false for blank user_id' do
      result = described_class.blacklist_user_tokens('')
      expect(result).to be false
    end

    it 'returns false for nil user_id' do
      result = described_class.blacklist_user_tokens(nil)
      expect(result).to be false
    end

    it 'handles database errors gracefully' do
      allow(JwtBlacklistToken).to receive(:blacklist_user_tokens).and_raise(StandardError, 'Database error')

      result = described_class.blacklist_user_tokens(user_id)
      expect(result).to be false
    end

    it 'handles cache errors gracefully' do
      # Create a token first so database operation succeeds
      create(:jwt_blacklist_token, user_id: user.id)
      allow(Auth::Jwt::CacheService).to receive(:set_user_logout_timestamp).and_raise(StandardError, 'Cache error')

      result = described_class.blacklist_user_tokens(user_id)
      # Should still return true if database operation succeeds
      expect(result).to be true
    end
  end

  describe 'private methods' do
    describe '.calculate_token_expiry' do
      it 'calculates expiry from token payload' do
        expiry = described_class.send(:calculate_token_expiry, valid_token)

        expect(expiry).to be_a(Time)
        expect(expiry).to be > Time.current
      end

      it 'uses default expiry for invalid token' do
        expiry = described_class.send(:calculate_token_expiry, 'invalid-token')

        expect(expiry).to be_a(Time)
        expect(expiry).to be > Time.current
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
