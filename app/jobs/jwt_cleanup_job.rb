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
    # Redis JWT keys use TTL; expiration is automatic. We do not delete cache here.
    # Optionally log current cache stats for monitoring.
    stats = Auth::Jwt::CacheService.stats
    Rails.logger.info "JWT cache stats: #{stats[:total_keys]} keys (blacklist: #{stats[:blacklist_keys]})"
    0
  rescue StandardError => e
    Rails.logger.error "Cache stats failed: #{e.message}"
    0
  end
end
