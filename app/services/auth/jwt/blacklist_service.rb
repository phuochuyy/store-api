# frozen_string_literal: true

module Auth
  module Jwt
    class BlacklistService
      class << self
        def blacklist_token(token, user_id: nil, token_type: 'access', reason: nil)
          return false if token.blank?

          expires_at = calculate_token_expiry(token)

          # Database stores user_id as bigint (integer)
          # No conversion needed - pass as is

          # Add to database
          result = JwtBlacklistToken.blacklist_token(
            token,
            user_id: user_id,
            token_type: token_type,
            reason: reason,
            expires_at: expires_at
          )

          # Update Redis cache
          if result
            CacheService.blacklist_token(token, expires_at: expires_at)
            # Invalidate validation cache
            CacheService.invalidate_validation(token)
          end

          Rails.logger.info "Token blacklisted: #{token[0..20]}..."
          true
        rescue StandardError => e
          Rails.logger.error "Failed to blacklist token: #{e.message}"
          false
        end

        def blacklisted?(token)
          return true if token.blank?

          # Check Redis cache first
          CacheService.blacklisted?(token)
        rescue StandardError => e
          Rails.logger.error "Failed to check token blacklist: #{e.message}"
          # Fallback to database on error
          begin
            JwtBlacklistToken.blacklisted?(token)
          rescue StandardError => db_error
            Rails.logger.error "Database error in blacklist check: #{db_error.message}"
            # Return false on error (fail open for availability)
            false
          end
        end

        def whitelist_token(token)
          return false if token.blank?

          # Remove from database
          JwtBlacklistToken.where(token: token).delete_all
          # Remove from Redis cache
          CacheService.whitelist_token(token)
          # Invalidate validation cache
          CacheService.invalidate_validation(token)

          Rails.logger.info "Token whitelisted: #{token[0..20]}..."
          true
        rescue StandardError => e
          Rails.logger.error "Failed to whitelist token: #{e.message}"
          false
        end

        def all_blacklisted_tokens
          JwtBlacklistToken.active
        rescue StandardError => e
          Rails.logger.error "Failed to get blacklisted tokens: #{e.message}"
          []
        end

        def clear_all_blacklisted_tokens
          count = JwtBlacklistToken.count
          JwtBlacklistToken.delete_all
          Rails.logger.info "Cleared #{count} blacklisted tokens"
          count
        rescue StandardError => e
          Rails.logger.error "Failed to clear blacklisted tokens: #{e.message}"
          0
        end

        def cleanup_expired_tokens
          JwtBlacklistToken.cleanup_expired
        rescue StandardError => e
          Rails.logger.error "Failed to cleanup expired tokens: #{e.message}"
          0
        end

        def blacklist_stats
          JwtBlacklistToken.stats
        rescue StandardError => e
          Rails.logger.error "Failed to get blacklist stats: #{e.message}"
          { total: 0, active: 0, expired: 0, by_type: {}, by_user: {} }
        end

        def blacklist_user_tokens(user_id, reason: 'User logout')
          return false if user_id.blank?

          # Convert user_id to integer for consistency (database stores as bigint)
          user_id_int = user_id.to_i
          return false if user_id_int.zero? && user_id.to_s != '0'

          Rails.logger.info "Blacklisting all tokens for user #{user_id_int}: #{reason}"

          # Step 1: Set logout timestamp to reject all tokens issued before now
          # This handles tokens we don't know about (not yet in database)
          # Continue even if Redis is not available (graceful degradation)
          begin
            CacheService.set_user_logout_timestamp(user_id_int)
          rescue StandardError => e
            Rails.logger.warn "Failed to set logout timestamp (Redis may not be available): #{e.message}"
          end

          # Step 2: Blacklist all existing tokens in database for this user
          db_result = JwtBlacklistToken.blacklist_user_tokens(user_id_int, reason: reason)
          return false unless db_result

          # Step 3: Invalidate all caches for this user
          # Continue even if Redis is not available
          begin
            CacheService.invalidate_user_tokens(user_id_int)
          rescue StandardError => e
            Rails.logger.warn "Failed to invalidate user tokens (Redis may not be available): #{e.message}"
          end

          # Step 4: Get all token hashes from Redis and invalidate their validation caches
          # Note: We can't reverse hashes to get original tokens, but we clear validation cache
          begin
            token_hashes = get_user_token_hashes(user_id_int)
            token_hashes.each do |_token_hash|
              # Validation cache will be invalidated by invalidate_user_tokens
              # Individual token blacklist cache will be checked on next validation
            end
          rescue StandardError => e
            Rails.logger.warn "Failed to get user token hashes (Redis may not be available): #{e.message}"
          end

          Rails.logger.info "Successfully blacklisted all tokens for user #{user_id_int}"
          true
        rescue StandardError => e
          Rails.logger.error "Failed to blacklist user tokens: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          false
        end

        private

        def calculate_token_expiry(token)
          # Use raw decode to avoid circular dependency with DecodeService
          payload = DecodeService.decode_raw(token)
          return Config::DEFAULT_EXPIRY.from_now unless payload&.dig('exp')

          Time.zone.at(payload['exp'])
        rescue StandardError
          Config::DEFAULT_EXPIRY.from_now
        end

        def get_user_token_hashes(user_id)
          return [] if user_id.blank?

          cache_key = CacheService.user_tokens_key(user_id)
          CacheService.redis.smembers(cache_key)
        rescue StandardError => e
          Rails.logger.error "Failed to get user token hashes: #{e.message}"
          []
        end
      end
    end
  end
end
