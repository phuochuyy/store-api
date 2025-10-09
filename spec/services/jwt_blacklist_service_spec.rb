require 'rails_helper'

RSpec.describe JwtBlacklistService, type: :service do
  let(:user) { create(:user) }
  let(:token) { JwtEncodeService.encode(user) }
  let(:refresh_token) { JwtEncodeService.encode_refresh_token(user) }

  describe '.blacklist_token' do
    it 'blacklists a token successfully' do
      expect do
        JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      end.to change(JwtBlacklistToken, :count).by(1)
    end

    it 'returns false for blank token' do
      expect(JwtBlacklistService.blacklist_token('')).to be false
      expect(JwtBlacklistService.blacklist_token(nil)).to be false
    end

    it 'handles duplicate tokens gracefully' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      expect(JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)).to be true
    end

    it 'sets correct token type' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s, token_type: 'access')
      blacklist_token = JwtBlacklistToken.last
      expect(blacklist_token.token_type).to eq('access')
    end

    it 'sets correct reason' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s, reason: 'User logout')
      blacklist_token = JwtBlacklistToken.last
      expect(blacklist_token.reason).to eq('User logout')
    end
  end

  describe '.blacklisted?' do
    it 'returns true for blacklisted token' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      expect(JwtBlacklistService.blacklisted?(token)).to be true
    end

    it 'returns false for non-blacklisted token' do
      expect(JwtBlacklistService.blacklisted?(token)).to be false
    end

    it 'returns true for blank token' do
      expect(JwtBlacklistService.blacklisted?('')).to be true
      expect(JwtBlacklistService.blacklisted?(nil)).to be true
    end

    it 'returns false for expired blacklisted token' do
      # Create an expired token
      expired_token = JwtEncodeService.encode(user, expiry: 1.hour.ago)
      JwtBlacklistService.blacklist_token(expired_token, user_id: user.id.to_s)

      # Manually set expiry to past
      JwtBlacklistToken.last.update!(expires_at: 1.hour.ago)

      expect(JwtBlacklistService.blacklisted?(expired_token)).to be false
    end
  end

  describe '.whitelist_token' do
    it 'removes token from blacklist' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      expect(JwtBlacklistService.blacklisted?(token)).to be true

      JwtBlacklistService.whitelist_token(token)
      expect(JwtBlacklistService.blacklisted?(token)).to be false
    end

    it 'returns false for blank token' do
      expect(JwtBlacklistService.whitelist_token('')).to be false
      expect(JwtBlacklistService.whitelist_token(nil)).to be false
    end
  end

  describe '.all_blacklisted_tokens' do
    it 'returns all active blacklisted tokens' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      JwtBlacklistService.blacklist_token(refresh_token, user_id: user.id.to_s)

      tokens = JwtBlacklistService.all_blacklisted_tokens
      expect(tokens.count).to eq(2)
    end

    it 'excludes expired tokens' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      expired_token = JwtEncodeService.encode(user, expiry: 1.hour.ago)
      JwtBlacklistService.blacklist_token(expired_token, user_id: user.id.to_s)

      # Manually set expiry to past
      JwtBlacklistToken.last.update!(expires_at: 1.hour.ago)

      tokens = JwtBlacklistService.all_blacklisted_tokens
      expect(tokens.count).to eq(1)
    end
  end

  describe '.clear_all_blacklisted_tokens' do
    it 'removes all blacklisted tokens' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      JwtBlacklistService.blacklist_token(refresh_token, user_id: user.id.to_s)

      expect do
        JwtBlacklistService.clear_all_blacklisted_tokens
      end.to change(JwtBlacklistToken, :count).to(0)
    end

    it 'returns count of cleared tokens' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      JwtBlacklistService.blacklist_token(refresh_token, user_id: user.id.to_s)

      count = JwtBlacklistService.clear_all_blacklisted_tokens
      expect(count).to eq(2)
    end
  end

  describe '.cleanup_expired_tokens' do
    it 'removes expired tokens' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s)
      expired_token = JwtEncodeService.encode(user, expiry: 1.hour.ago)
      JwtBlacklistService.blacklist_token(expired_token, user_id: user.id.to_s)

      # Manually set expiry to past
      JwtBlacklistToken.last.update!(expires_at: 1.hour.ago)

      expect do
        JwtBlacklistService.cleanup_expired_tokens
      end.to change(JwtBlacklistToken, :count).by(-1)
    end
  end

  describe '.blacklist_stats' do
    it 'returns statistics' do
      JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s, token_type: 'access')
      JwtBlacklistService.blacklist_token(refresh_token, user_id: user.id.to_s, token_type: 'refresh')

      stats = JwtBlacklistService.blacklist_stats
      expect(stats[:total]).to eq(2)
      expect(stats[:active]).to eq(2)
      expect(stats[:expired]).to eq(0)
      expect(stats[:by_type]['access']).to eq(1)
      expect(stats[:by_type]['refresh']).to eq(1)
    end
  end

  describe '.blacklist_user_tokens' do
    it 'blacklists all tokens for a user' do
      result = JwtBlacklistService.blacklist_user_tokens(user.id.to_s, reason: 'Security breach')
      expect(result).to be true
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(JwtBlacklistToken).to receive(:blacklisted?).and_raise(ActiveRecord::StatementInvalid.new('Database error'))

      expect(JwtBlacklistService.blacklisted?(token)).to be false
    end

    it 'logs errors appropriately' do
      allow(JwtBlacklistToken).to receive(:blacklisted?).and_raise(StandardError.new('Test error'))

      expect(Rails.logger).to receive(:error).with(/Failed to check token blacklist/)
      JwtBlacklistService.blacklisted?(token)
    end
  end
end
