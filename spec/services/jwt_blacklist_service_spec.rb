# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JwtBlacklistService, type: :service do
  let(:user) { create(:user) }
  let(:token) { JwtEncodeService.encode(user) }
  let(:redis) { Redis.new(RedisConfig.connection_options) }

  before do
    # Clear Redis before each test
    redis.flushdb
  end

  after do
    # Clean up Redis after each test
    redis.flushdb
  end

  describe '.blacklist_token' do
    context 'with valid token' do
      it 'adds token to blacklist' do
        expect(JwtBlacklistService.blacklist_token(token)).to be true
        expect(JwtBlacklistService.blacklisted?(token)).to be true
      end

      it 'sets TTL for blacklisted token' do
        JwtBlacklistService.blacklist_token(token, ttl: 3600)

        # Check that the token exists in Redis
        token_hash = Digest::SHA256.hexdigest(token)
        key = "jwt_blacklist:#{token_hash}"
        expect(redis.exists?(key)).to be true

        # Check TTL is set (should be around 3600 seconds or token expiry)
        ttl = redis.ttl(key)
        expect(ttl).to be > 0
        expect(ttl).to be <= 86_400 # Max 24 hours
      end
    end

    context 'with blank token' do
      it 'returns false' do
        expect(JwtBlacklistService.blacklist_token('')).to be false
        expect(JwtBlacklistService.blacklist_token(nil)).to be false
      end
    end

    context 'with invalid token' do
      it 'handles invalid token gracefully' do
        invalid_token = 'invalid.token.here'
        expect(JwtBlacklistService.blacklist_token(invalid_token)).to be true
        expect(JwtBlacklistService.blacklisted?(invalid_token)).to be true
      end
    end
  end

  describe '.blacklisted?' do
    context 'when token is blacklisted' do
      before do
        JwtBlacklistService.blacklist_token(token)
      end

      it 'returns true' do
        expect(JwtBlacklistService.blacklisted?(token)).to be true
      end
    end

    context 'when token is not blacklisted' do
      it 'returns false' do
        expect(JwtBlacklistService.blacklisted?(token)).to be false
      end
    end

    context 'with blank token' do
      it 'returns true for blank tokens' do
        expect(JwtBlacklistService.blacklisted?('')).to be true
        expect(JwtBlacklistService.blacklisted?(nil)).to be true
      end
    end
  end

  describe '.whitelist_token' do
    context 'when token is blacklisted' do
      before do
        JwtBlacklistService.blacklist_token(token)
      end

      it 'removes token from blacklist' do
        expect(JwtBlacklistService.blacklisted?(token)).to be true
        expect(JwtBlacklistService.whitelist_token(token)).to be true
        expect(JwtBlacklistService.blacklisted?(token)).to be false
      end
    end

    context 'when token is not blacklisted' do
      it 'returns true' do
        expect(JwtBlacklistService.whitelist_token(token)).to be true
      end
    end

    context 'with blank token' do
      it 'returns false' do
        expect(JwtBlacklistService.whitelist_token('')).to be false
        expect(JwtBlacklistService.whitelist_token(nil)).to be false
      end
    end
  end

  describe '.all_blacklisted_tokens' do
    context 'when no tokens are blacklisted' do
      it 'returns empty array' do
        expect(JwtBlacklistService.all_blacklisted_tokens).to eq([])
      end
    end

    context 'when tokens are blacklisted' do
      let(:token2) { JwtEncodeService.encode(create(:user)) }
      let(:token3) { JwtEncodeService.encode(create(:user)) }

      before do
        JwtBlacklistService.blacklist_token(token)
        JwtBlacklistService.blacklist_token(token2)
        JwtBlacklistService.blacklist_token(token3)
      end

      it 'returns all blacklisted token keys' do
        keys = JwtBlacklistService.all_blacklisted_tokens
        expect(keys.count).to eq(3)
        expect(keys.all? { |key| key.start_with?('jwt_blacklist:') }).to be true
      end
    end
  end

  describe '.clear_all_blacklisted_tokens' do
    context 'when tokens are blacklisted' do
      let(:token2) { JwtEncodeService.encode(create(:user)) }

      before do
        JwtBlacklistService.blacklist_token(token)
        JwtBlacklistService.blacklist_token(token2)
      end

      it 'clears all blacklisted tokens' do
        expect(JwtBlacklistService.all_blacklisted_tokens.count).to eq(2)

        cleared_count = JwtBlacklistService.clear_all_blacklisted_tokens
        expect(cleared_count).to eq(2)
        expect(JwtBlacklistService.all_blacklisted_tokens).to eq([])
      end
    end

    context 'when no tokens are blacklisted' do
      it 'returns 0' do
        expect(JwtBlacklistService.clear_all_blacklisted_tokens).to eq(0)
      end
    end
  end

  describe '.blacklist_stats' do
    context 'when no tokens are blacklisted' do
      it 'returns empty stats' do
        stats = JwtBlacklistService.blacklist_stats
        expect(stats[:total_blacklisted]).to eq(0)
        expect(stats[:memory_usage]).to eq(0)
      end
    end

    context 'when tokens are blacklisted' do
      before do
        JwtBlacklistService.blacklist_token(token)
        JwtBlacklistService.blacklist_token(JwtEncodeService.encode(create(:user)))
      end

      it 'returns correct stats' do
        stats = JwtBlacklistService.blacklist_stats
        expect(stats[:total_blacklisted]).to eq(2)
        expect(stats[:memory_usage]).to be > 0
      end
    end
  end

  describe 'integration with JwtDecodeService' do
    context 'when token is blacklisted' do
      before do
        JwtBlacklistService.blacklist_token(token)
      end

      it 'prevents token from being decoded' do
        expect(JwtDecodeService.decode(token)).to be_nil
        expect(JwtDecodeService.decode_user(token)).to be_nil
      end

      it 'returns appropriate error in validate_token' do
        result = JwtDecodeService.validate_token(token)
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('Token has been revoked')
      end
    end

    context 'when token is not blacklisted' do
      it 'allows token to be decoded normally' do
        expect(JwtDecodeService.decode(token)).not_to be_nil
        expect(JwtDecodeService.decode_user(token)).to eq(user)
      end
    end
  end

  describe 'error handling' do
    context 'when Redis is unavailable' do
      before do
        allow_any_instance_of(Redis).to receive(:setex).and_raise(Redis::ConnectionError)
        allow_any_instance_of(Redis).to receive(:exists?).and_raise(Redis::ConnectionError)
      end

      it 'handles Redis connection errors gracefully' do
        expect(JwtBlacklistService.blacklist_token(token)).to be false
        expect(JwtBlacklistService.blacklisted?(token)).to be false
      end
    end
  end
end
