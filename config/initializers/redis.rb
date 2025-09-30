# frozen_string_literal: true

# Redis configuration for different environments
module RedisConfig
  def self.url
    case Rails.env
    when 'test'
      ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
    when 'development'
      ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    when 'production'
      ENV.fetch('REDIS_URL', 'redis://redis:6379/0')
    else
      ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    end
  end

  def self.connection_options
    {
      url: url,
      timeout: 1,
      reconnect_attempts: 3
    }
  end
end

# Set global Redis URL for the application
Rails.application.config.redis_url = RedisConfig.url
