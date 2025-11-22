# frozen_string_literal: true

# Redis helper for tests
# Provides utilities to manage Redis state during tests

module RedisHelper
  def redis_url
    # In Docker: redis://redis:6379/1, locally: redis://localhost:6379/1
    ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  end

  def clear_redis_cache
    return unless defined?(Redis)

    begin
      redis = Redis.new(url: redis_url)
      # Clear all keys in test namespace
      redis.keys('jwt:auth:*').each { |key| redis.del(key) }
      redis.keys('store_api_test:*').each { |key| redis.del(key) }
    rescue Redis::BaseError, Errno::ECONNREFUSED => e
      # Redis not available, skip
      Rails.logger.debug { "Redis not available for test cleanup: #{e.message}" } if defined?(Rails)
    end
  end

  def with_redis_available
    redis = Redis.new(url: redis_url)
    redis.ping
    yield
  rescue Redis::BaseError, Errno::ECONNREFUSED
    skip 'Redis not available'
  end

  def redis_available?
    redis = Redis.new(url: redis_url)
    redis.ping
    true
  rescue Redis::BaseError, Errno::ECONNREFUSED
    false
  end
end

RSpec.configure do |config|
  config.include RedisHelper, type: :service
end
