# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::Jwt::CacheService, type: :service do
  let(:user) { create(:user) }
  let(:token) { Auth::Jwt::EncodeService.encode(user) }
  let(:refresh_token) { Auth::Jwt::EncodeService.encode_refresh_token(user) }

  before do
    # Skip tests if Redis not available
    skip 'Redis not available' unless redis_available?
    
    # Clear cache before each test
    clear_redis_cache
    described_class.clear_all
  end

  after do
    # Clean up after tests
    clear_redis_cache
    described_class.clear_all
  end

  def redis_available?
    # In Docker: redis://redis:6379/1, locally: redis://localhost:6379/1
    redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
    redis = Redis.new(url: redis_url)
    redis.ping
    true
  rescue Redis::BaseError, Errno::ECONNREFUSED
    false
  end

  describe '.blacklisted?' do
    context 'when token is not blacklisted' do
      it 'returns false' do
        expect(described_class.blacklisted?(token)).to be false
      end

      it 'caches the result' do
        # First call - should check cache and database
        result1 = described_class.blacklisted?(token)
        expect(result1).to be false

        # Second call - should use cache (no database call)
        allow(JwtBlacklistToken).to receive(:blacklisted?).and_raise('Should not call database')
        result2 = described_class.blacklisted?(token)
        expect(result2).to be false
      end
    end

    context 'when token is blacklisted' do
      before do
        JwtBlacklistToken.create!(
          token: token,
          expires_at: 1.hour.from_now,
          token_type: 'access'
        )
      end

      it 'returns true' do
        expect(described_class.blacklisted?(token)).to be true
      end

      it 'caches the result' do
        described_class.blacklisted?(token)
        expect(described_class.blacklisted?(token)).to be true
      end
    end

    context 'when token is blank' do
      it 'returns true' do
        expect(described_class.blacklisted?('')).to be true
        expect(described_class.blacklisted?(nil)).to be true
      end
    end

    context 'when Redis fails' do
      before do
        allow(described_class.redis).to receive(:get).and_raise(Redis::BaseError.new('Connection failed'))
      end

      it 'falls back to database' do
        expect(described_class.blacklisted?(token)).to be false
      end
    end
  end

  describe '.blacklist_token' do
    it 'marks token as blacklisted in cache' do
      expires_at = 1.hour.from_now
      described_class.blacklist_token(token, expires_at: expires_at)

      expect(described_class.blacklisted?(token)).to be true
    end

    it 'sets appropriate TTL' do
      expires_at = 2.hours.from_now
      described_class.blacklist_token(token, expires_at: expires_at)

      cache_key = described_class.blacklist_key(token)
      ttl = described_class.redis.ttl(cache_key)
      expect(ttl).to be_within(60).of(2.hours.to_i)
    end
  end

  describe '.whitelist_token' do
    before do
      described_class.blacklist_token(token)
    end

    it 'removes token from blacklist cache' do
      expect(described_class.blacklisted?(token)).to be true

      described_class.whitelist_token(token)

      expect(described_class.blacklisted?(token)).to be false
    end
  end

  describe '.cache_user' do
    it 'caches user data' do
      described_class.cache_user(user)

      cached = described_class.get_cached_user(user.id)
      expect(cached).to be_a(User)
      expect(cached.id).to eq(user.id)
    end

    it 'sets cache expiry' do
      described_class.cache_user(user)

      cache_key = described_class.user_key(user.id)
      ttl = described_class.redis.ttl(cache_key)
      expect(ttl).to be_within(60).of(1.hour.to_i)
    end
  end

  describe '.get_cached_user' do
    context 'when user is cached' do
      before do
        described_class.cache_user(user)
      end

      it 'returns user from cache' do
        cached = described_class.get_cached_user(user.id)
        expect(cached).to be_a(User)
        expect(cached.id).to eq(user.id)
      end
    end

    context 'when user is not cached' do
      it 'returns nil' do
        expect(described_class.get_cached_user(user.id)).to be_nil
      end
    end
  end

  describe '.invalidate_user' do
    before do
      described_class.cache_user(user)
    end

    it 'removes user from cache' do
      expect(described_class.get_cached_user(user.id)).to be_present

      described_class.invalidate_user(user.id)

      expect(described_class.get_cached_user(user.id)).to be_nil
    end
  end

  describe '.cache_validation' do
    let(:validation_result) do
      { valid: true, user: user, payload: { user_id: user.id } }
    end

    it 'caches validation result' do
      described_class.cache_validation(token, validation_result)

      cached = described_class.get_cached_validation(token)
      expect(cached[:valid]).to be true
      expect(cached[:user].id).to eq(user.id)
    end

    it 'only caches successful validations' do
      failed_result = { valid: false, error: 'Invalid token' }
      described_class.cache_validation(token, failed_result)

      expect(described_class.get_cached_validation(token)).to be_nil
    end
  end

  describe '.get_cached_validation' do
    context 'when validation is cached' do
      before do
        result = { valid: true, user: user, payload: { user_id: user.id } }
        described_class.cache_validation(token, result)
      end

      it 'returns cached validation result' do
        cached = described_class.get_cached_validation(token)
        expect(cached[:valid]).to be true
        expect(cached[:user].id).to eq(user.id)
      end
    end

    context 'when validation is not cached' do
      it 'returns nil' do
        expect(described_class.get_cached_validation(token)).to be_nil
      end
    end
  end

  describe '.track_user_token' do
    it 'tracks token for user' do
      described_class.track_user_token(user.id, token)

      cache_key = described_class.user_tokens_key(user.id)
      token_hash = Digest::SHA256.hexdigest(token)
      expect(described_class.redis.smembers(cache_key)).to include(token_hash)
    end
  end

  describe '.invalidate_user_tokens' do
    before do
      described_class.track_user_token(user.id, token)
      described_class.track_user_token(user.id, refresh_token)
      described_class.cache_user(user)
    end

    it 'invalidates all user tokens and cache' do
      expect(described_class.get_cached_user(user.id)).to be_present

      described_class.invalidate_user_tokens(user.id)

      expect(described_class.get_cached_user(user.id)).to be_nil
      cache_key = described_class.user_tokens_key(user.id)
      expect(described_class.redis.exists(cache_key)).to be 0
    end
  end

  describe '.stats' do
    before do
      described_class.blacklist_token(token)
      described_class.cache_user(user)
      described_class.cache_validation(refresh_token, { valid: true, user: user, payload: {} })
      described_class.track_user_token(user.id, token)
    end

    it 'returns cache statistics' do
      stats = described_class.stats

      expect(stats[:total_keys]).to be > 0
      expect(stats[:blacklist_keys]).to be >= 1
      expect(stats[:user_keys]).to be >= 1
      expect(stats[:validation_keys]).to be >= 1
    end
  end

  describe '.clear_all' do
    before do
      described_class.blacklist_token(token)
      described_class.cache_user(user)
    end

    it 'clears all JWT caches' do
      expect(described_class.stats[:total_keys]).to be > 0

      cleared = described_class.clear_all

      expect(cleared).to be > 0
      expect(described_class.stats[:total_keys]).to eq(0)
    end
  end
end

