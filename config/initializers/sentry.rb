# frozen_string_literal: true

# Sentry configuration for error tracking
# See: https://docs.sentry.io/platforms/ruby/

Sentry.init do |config|
  config.dsn = ENV.fetch('SENTRY_DSN', nil)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set environment
  config.environment = Rails.env

  # Set release version
  config.release = ENV.fetch('APP_VERSION', '1.0.0')

  # Filter sensitive data
  config.before_send = lambda do |event, _hint|
    # Filter out sensitive parameters
    if event.request && event.request.data
      event.request.data = event.request.data.except('password', 'password_confirmation', 'token')
    end
    event
  end

  # Set sample rate (0.0 to 1.0)
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # Ignore certain exceptions
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound'
  ]

  # Only send errors in production and staging
  config.enabled_environments = %w[production staging]

  # Set user context
  config.before_send = lambda do |event, hint|
    if hint[:scope] && hint[:scope][:user]
      event.user = hint[:scope][:user]
    end
    event
  end
end

# Only initialize Sentry if DSN is provided
if ENV['SENTRY_DSN'].blank?
  Rails.logger.info 'Sentry DSN not configured, error tracking disabled'
end

