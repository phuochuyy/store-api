# frozen_string_literal: true

# OkComputer health check configuration
# See: https://github.com/sportngin/okcomputer

OkComputer.mount_at = 'health'

# Database check
OkComputer::Registry.register 'database', OkComputer::ActiveRecordCheck.new

# Redis check
class RedisCheck < OkComputer::Check
  def check
    redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    redis = Redis.new(url: redis_url)
    redis.ping
    mark_message 'Redis connection successful'
  rescue StandardError => e
    mark_failure
    mark_message "Redis connection failed: #{e.message}"
  end
end

OkComputer::Registry.register 'redis', RedisCheck.new

# Sidekiq check
class SidekiqCheck < OkComputer::Check
  def check
    if defined?(Sidekiq)
      stats = Sidekiq::Stats.new
      mark_message({
        processed: stats.processed,
        failed: stats.failed,
        busy: stats.busy,
        enqueued: stats.enqueued
      }.to_json)
    else
      mark_message 'Sidekiq not configured'
    end
  rescue StandardError => e
    mark_failure
    mark_message "Sidekiq check failed: #{e.message}"
  end
end

OkComputer::Registry.register 'sidekiq', SidekiqCheck.new

# Custom application check
class ApplicationCheck < OkComputer::Check
  def check
    mark_message 'Application is running'
  end
end

OkComputer::Registry.register 'application', ApplicationCheck.new

# Version check
class VersionCheck < OkComputer::Check
  def check
    mark_message({
      version: ENV.fetch('APP_VERSION', '1.0.0'),
      environment: Rails.env,
      rails_version: Rails.version
    }.to_json)
  end
end

OkComputer::Registry.register 'version', VersionCheck.new

