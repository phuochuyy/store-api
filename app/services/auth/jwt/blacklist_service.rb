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
          # NOTE: This is a placeholder - actual implementation would need to
          # blacklist all active tokens for the user
          # For now, we invalidate all caches for the user
          CacheService.invalidate_user_tokens(user_id)
          JwtBlacklistToken.blacklist_user_tokens(user_id, reason: reason)
        rescue StandardError => e
          Rails.logger.error "Failed to blacklist user tokens: #{e.message}"
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
      end
    end
  end
end
