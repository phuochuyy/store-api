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

  # Mask passwords, tokens, emails... (the app's filter_parameters) in events and breadcrumbs, at
  # any depth. SentryScrubber lives in lib/, which is autoloaded, so it is looked up when an event
  # is sent rather than while initializers run.
  config.before_send = ->(event, hint) { SentryScrubber.scrub_event(event, hint) }
  config.before_breadcrumb = ->(breadcrumb, hint) { SentryScrubber.scrub_breadcrumb(breadcrumb, hint) }

  # Set sample rate (0.0 to 1.0)
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # Ignore certain exceptions
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound'
  ]

  # Only send errors in production and staging
  config.enabled_environments = %w[production staging]
end

# Only initialize Sentry if DSN is provided
if ENV['SENTRY_DSN'].blank?
  Rails.logger.info 'Sentry DSN not configured, error tracking disabled'
end

