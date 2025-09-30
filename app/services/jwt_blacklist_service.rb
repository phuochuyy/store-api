# frozen_string_literal: true

class JwtBlacklistService
  # Redis key prefix for blacklisted tokens
  BLACKLIST_PREFIX = 'jwt_blacklist:'

  # Default TTL for blacklisted tokens (24 hours)
  DEFAULT_TTL = 24.hours.to_i

  class << self
    # Add a token to the blacklist
    # @param token [String] The JWT token to blacklist
    # @param ttl [Integer] Time to live in seconds (default: 24 hours)
    # @return [Boolean] True if successfully blacklisted
    def blacklist_token(token, ttl: DEFAULT_TTL)
      return false if token.blank?

      # Get token expiry from JWT payload
      token_ttl = calculate_token_ttl(token, ttl)

      # Add to Redis with TTL
      redis.setex(blacklist_key(token), token_ttl, '1')

      Rails.logger.info "Token blacklisted: #{token[0..20]}..."
      true
    rescue StandardError => e
      Rails.logger.error "Failed to blacklist token: #{e.message}"
      false
    end

    # Check if a token is blacklisted
    # @param token [String] The JWT token to check
    # @return [Boolean] True if token is blacklisted
    def blacklisted?(token)
      return true if token.blank?

      redis.exists?(blacklist_key(token))
    rescue StandardError => e
      Rails.logger.error "Failed to check token blacklist: #{e.message}"
      # In case of Redis error, assume token is not blacklisted
      # This prevents false positives that would lock out users
      false
    end

    # Remove a token from the blacklist (useful for testing or admin operations)
    # @param token [String] The JWT token to remove from blacklist
    # @return [Boolean] True if successfully removed
    def whitelist_token(token)
      return false if token.blank?

      redis.del(blacklist_key(token))
      Rails.logger.info "Token whitelisted: #{token[0..20]}..."
      true
    rescue StandardError => e
      Rails.logger.error "Failed to whitelist token: #{e.message}"
      false
    end

    # Get all blacklisted tokens (for admin purposes)
    # @return [Array<String>] Array of blacklisted token keys
    def all_blacklisted_tokens
      redis.keys("#{BLACKLIST_PREFIX}*")
    rescue StandardError => e
      Rails.logger.error "Failed to get blacklisted tokens: #{e.message}"
      []
    end

    # Clear all blacklisted tokens (for testing or maintenance)
    # @return [Integer] Number of tokens cleared
    def clear_all_blacklisted_tokens
      keys = all_blacklisted_tokens
      return 0 if keys.empty?

      redis.del(*keys)
      Rails.logger.info "Cleared #{keys.count} blacklisted tokens"
      keys.count
    rescue StandardError => e
      Rails.logger.error "Failed to clear blacklisted tokens: #{e.message}"
      0
    end

    # Get blacklist statistics
    # @return [Hash] Statistics about blacklisted tokens
    def blacklist_stats
      keys = all_blacklisted_tokens
      {
        total_blacklisted: keys.count,
        memory_usage: calculate_memory_usage(keys)
      }
    rescue StandardError => e
      Rails.logger.error "Failed to get blacklist stats: #{e.message}"
      { total_blacklisted: 0, memory_usage: 0 }
    end

    private

    # Get Redis connection
    # @return [Redis] Redis connection
    def redis
      @redis ||= Redis.new(RedisConfig.connection_options)
    end

    # Generate Redis key for blacklisted token
    # @param token [String] The JWT token
    # @return [String] Redis key
    def blacklist_key(token)
      # Use a hash of the token to avoid storing full tokens in Redis keys
      token_hash = Digest::SHA256.hexdigest(token)
      "#{BLACKLIST_PREFIX}#{token_hash}"
    end

    # Calculate TTL for blacklisted token
    # @param token [String] The JWT token
    # @param default_ttl [Integer] Default TTL in seconds
    # @return [Integer] TTL in seconds
    def calculate_token_ttl(token, default_ttl)
      # Try to get token expiry from JWT payload
      payload = JwtDecodeService.decode(token)
      return default_ttl unless payload&.dig('exp')

      # Calculate remaining time until token expires
      exp_time = payload['exp']
      remaining_time = exp_time - Time.current.to_i

      # Use remaining time if positive, otherwise use default TTL
      [remaining_time, default_ttl].max
    rescue StandardError
      # If we can't decode the token, use default TTL
      default_ttl
    end

    # Calculate memory usage for blacklisted tokens
    # @param keys [Array<String>] Array of Redis keys
    # @return [Integer] Memory usage in bytes
    def calculate_memory_usage(keys)
      return 0 if keys.empty?

      # Get memory usage for each key
      keys.sum do |key|
        redis.memory(:usage, key) || 0
      end
    rescue StandardError
      0
    end
  end
end
