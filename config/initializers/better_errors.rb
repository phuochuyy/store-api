if Rails.env.development?
  BetterErrors.application_root = File.expand_path("..", __dir__)

  # Allow better_errors to work in Docker
  BetterErrors::Middleware.allow_ip! "0.0.0.0/0" if defined?(BetterErrors)
end
