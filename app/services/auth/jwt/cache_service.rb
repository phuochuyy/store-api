# frozen_string_literal: true

require 'digest'

module Auth
  module Jwt
    # rubocop:disable Metrics/ClassLength
    class CacheService
      class << self
        # Cache namespace for JWT tokens
        CACHE_NAMESPACE = 'jwt:auth'
        CACHE_EXPIRY = 1.hour

        # Get Redis connection
        def redis
          @redis ||= begin
            redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
            Redis.new(url: redis_url)
          end
        end

        # Cache key for blacklist check
        def blacklist_key(token)
          "#{CACHE_NAMESPACE}:blacklist:#{Digest::SHA256.hexdigest(token)}"
        end

        # Cache key for user lookup
        def user_key(user_id)
          "#{CACHE_NAMESPACE}:user:#{user_id}"
        end

        # Cache key for token validation
        def validation_key(token)
          "#{CACHE_NAMESPACE}:validation:#{Digest::SHA256.hexdigest(token)}"
        end

        # Cache key for user's active tokens (for revoke all)
        def user_tokens_key(user_id)
          "#{CACHE_NAMESPACE}:user_tokens:#{user_id}"
        end

        # Cache key for user logout timestamp
        def user_logout_timestamp_key(user_id)
          "#{CACHE_NAMESPACE}:logout_timestamp:#{user_id}"
        end

        # Check if token is blacklisted (with cache)
        def blacklisted?(token)
          return true if token.blank?

          cache_key = blacklist_key(token)
          cached = redis.get(cache_key)

          return cached == '1' if cached

          # If not in cache, check database
          is_blacklisted = JwtBlacklistToken.blacklisted?(token)
          # Cache the result (cache for shorter time if blacklisted)
          expiry = is_blacklisted ? 24.hours : CACHE_EXPIRY
          redis.setex(cache_key, expiry.to_i, is_blacklisted ? '1' : '0')

          is_blacklisted
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in blacklisted? check: #{e.message}"
          # Fallback to database on Redis error
          JwtBlacklistToken.blacklisted?(token)
        end

        # Mark token as blacklisted in cache
        def blacklist_token(token, expires_at: nil)
          return false if token.blank?

          cache_key = blacklist_key(token)
          expiry = expires_at || 24.hours.from_now
          ttl = [expiry.to_i - Time.current.to_i, 0].max

          redis.setex(cache_key, ttl, '1')
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in blacklist_token: #{e.message}"
          false
        end

        # Remove token from blacklist cache
        def whitelist_token(token)
          return false if token.blank?

          cache_key = blacklist_key(token)
          redis.del(cache_key)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in whitelist_token: #{e.message}"
          false
        end

        # Cache user data (cache user_id as a marker)
        def cache_user(user)
          return nil unless user

          cache_key = user_key(user.id)
          # Cache a simple marker (user_id) to indicate user was recently accessed
          # This allows us to quickly check if user exists before querying database
          redis.setex(cache_key, CACHE_EXPIRY.to_i, user.id.to_s)
          user
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in cache_user: #{e.message}"
          user
        end

        # Get cached user (returns User object if cached, nil otherwise)
        # Note: We cache user_id only, then fetch from database
        # This ensures we always get a proper User object with all associations
        def get_cached_user(user_id)
          return nil unless user_id

          cache_key = user_key(user_id)
          cached = redis.get(cache_key)

          return nil unless cached

          # If cached, fetch user from database
          # The cache key existence means user was recently accessed
          User.find_by(id: user_id)
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in get_cached_user: #{e.message}"
          nil
        end

        # Invalidate user cache
        def invalidate_user(user_id)
          return false unless user_id

          cache_key = user_key(user_id)
          redis.del(cache_key)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in invalidate_user: #{e.message}"
          false
        end

        # Cache token validation result
        def cache_validation(token, result)
          return unless token.present? && result.is_a?(Hash)

          cache_key = validation_key(token)
          # Only cache successful validations
          if result[:valid] && result[:user]
            validation_data = {
              valid: true,
              user_id: result[:user].id,
              cached_at: Time.current.to_i
            }
            redis.setex(cache_key, 15.minutes.to_i, validation_data.to_json)
          end
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in cache_validation: #{e.message}"
        end

        # Get cached validation result
        def get_cached_validation(token)
          return nil if token.blank?

          cache_key = validation_key(token)
          cached = redis.get(cache_key)

          return nil unless cached

          validation_data = JSON.parse(cached)
          return nil unless validation_data['valid']

          # Fetch user from cache or database
          user = get_cached_user(validation_data['user_id']) || User.find_by(id: validation_data['user_id'])
          return nil unless user

          { valid: true, user: user, payload: { user_id: user.id } }
        rescue JSON::ParserError, Redis::BaseError => e
          Rails.logger.error "Redis error in get_cached_validation: #{e.message}"
          nil
        end

        # Invalidate validation cache for a token
        def invalidate_validation(token)
          return false if token.blank?

          cache_key = validation_key(token)
          redis.del(cache_key)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in invalidate_validation: #{e.message}"
          false
        end

        # Track user's active tokens (for revoke all functionality)
        def track_user_token(user_id, token)
          return false unless user_id && token.present?

          cache_key = user_tokens_key(user_id)
          token_hash = Digest::SHA256.hexdigest(token)
          redis.sadd(cache_key, token_hash)
          redis.expire(cache_key, 7.days.to_i) # Refresh tokens expire in 7 days
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in track_user_token: #{e.message}"
          false
        end

        # Invalidate all tokens for a user
        def invalidate_user_tokens(user_id)
          return false unless user_id

          cache_key = user_tokens_key(user_id)
          token_hashes = redis.smembers(cache_key)

          # Invalidate validation cache for all tokens
          token_hashes.each do |token_hash|
            # We can't reverse the hash, but we can clear the user cache
            # and let validation fail naturally
          end

          # Clear the user tokens set
          redis.del(cache_key)
          # Also invalidate user cache
          invalidate_user(user_id)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in invalidate_user_tokens: #{e.message}"
          false
        end

        # Set logout timestamp for user (to reject tokens issued before this time)
        def set_user_logout_timestamp(user_id)
          return false unless user_id

          timestamp_key = user_logout_timestamp_key(user_id)
          logout_timestamp = Time.current.to_i
          # Store for 7 days (max refresh token expiry)
          redis.setex(timestamp_key, 7.days.to_i, logout_timestamp.to_s)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in set_user_logout_timestamp: #{e.message}"
          false
        end

        # Get logout timestamp for user
        def get_user_logout_timestamp(user_id)
          return nil unless user_id

          timestamp_key = user_logout_timestamp_key(user_id)
          timestamp_str = redis.get(timestamp_key)
          return nil unless timestamp_str

          Time.zone.at(timestamp_str.to_i)
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in get_user_logout_timestamp: #{e.message}"
          nil
        end

        # Clear logout timestamp for user
        def clear_user_logout_timestamp(user_id)
          return false unless user_id

          timestamp_key = user_logout_timestamp_key(user_id)
          redis.del(timestamp_key)
          true
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in clear_user_logout_timestamp: #{e.message}"
          false
        end

        # Clear all JWT caches (use with caution)
        def clear_all
          pattern = "#{CACHE_NAMESPACE}:*"
          keys = redis.keys(pattern)
          redis.del(*keys) if keys.any?
          keys.count
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in clear_all: #{e.message}"
          0
        end

        # Get cache statistics
        def stats
          pattern = "#{CACHE_NAMESPACE}:*"
          keys = redis.keys(pattern)

          {
            total_keys: keys.count,
            blacklist_keys: keys.count { |k| k.include?(':blacklist:') },
            user_keys: keys.count { |k| k.include?(':user:') },
            validation_keys: keys.count { |k| k.include?(':validation:') },
            user_tokens_keys: keys.count { |k| k.include?(':user_tokens:') }
          }
        rescue Redis::BaseError => e
          Rails.logger.error "Redis error in stats: #{e.message}"
          { total_keys: 0, blacklist_keys: 0, user_keys: 0, validation_keys: 0, user_tokens_keys: 0 }
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
