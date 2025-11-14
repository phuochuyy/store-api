# frozen_string_literal: true

# Lograge configuration for structured logging
# See: https://github.com/roidrage/lograge

Rails.application.configure do
  config.lograge.enabled = true

  # Add custom options to log
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      ip: event.payload[:ip],
      user_agent: event.payload[:user_agent]
    }.compact
  end

  # Customize log format
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Add custom fields to log
  config.lograge.custom_payload do |controller|
    {
      user_id: controller.respond_to?(:current_user) ? controller.current_user&.id : nil,
      ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent
    }
  end

  # Ignore certain paths
  config.lograge.ignore_actions = [
    'Api::V1::HealthController#index',
    'OkComputer::OkComputerController#index'
  ]

  # Log SQL queries in development
  if Rails.env.development?
    config.lograge.keep_original_rails_log = true
    config.colorize_logging = true
  end
end

