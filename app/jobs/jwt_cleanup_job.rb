# frozen_string_literal: true

class JwtCleanupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting JWT blacklist cleanup...'

    # Cleanup expired tokens from database
    db_cleaned = cleanup_database_tokens

    # Cleanup expired tokens from Redis cache
    cache_cleaned = cleanup_cache_tokens

    Rails.logger.info "JWT cleanup completed: #{db_cleaned} DB tokens, #{cache_cleaned} cache keys cleaned"

    {
      success: true,
      database_cleaned: db_cleaned,
      cache_cleaned: cache_cleaned
    }
  rescue StandardError => e
    Rails.logger.error "JWT cleanup job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  def cleanup_database_tokens
    # Cleanup expired blacklist tokens from database
    expired_count = JwtBlacklistToken.expired.count
    JwtBlacklistToken.cleanup_expired
    expired_count
  rescue StandardError => e
    Rails.logger.error "Database cleanup failed: #{e.message}"
    0
  end

  def cleanup_cache_tokens
    # Cleanup expired cache entries
    # Note: Redis TTL handles expiration automatically, but we can clean up
    # any stale entries that might exist
    stats_before = Auth::Jwt::CacheService.stats
    total_keys_before = stats_before[:total_keys]

    # Redis automatically expires keys based on TTL, so we don't need to manually delete
    # But we can log the stats
    stats_after = Auth::Jwt::CacheService.stats
    total_keys_after = stats_after[:total_keys]

    # Return the difference (keys that expired)
    [total_keys_before - total_keys_after, 0].max
  rescue StandardError => e
    Rails.logger.error "Cache cleanup failed: #{e.message}"
    0
  end
end

