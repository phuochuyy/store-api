require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module StoreApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Add custom paths to autoload
    config.autoload_paths += %W[
      #{config.root}/app/services
      #{config.root}/app/validators
      #{config.root}/app/policies
      #{config.root}/app/middleware
    ]

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Add Rack::Attack middleware for rate limiting
    config.middleware.use Rack::Attack

    # Set default URL options for general URL generation
    config.default_url_options = { host: 'localhost', port: 3000, protocol: 'http' }

    # Database connection retry configuration
    config.after_initialize do

      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute('SELECT 1') if connection.active?
      end
      Rails.logger.info 'Database connection established successfully'
    rescue ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad => e
      Rails.logger.warn "Database connection failed: #{e.message}. Retrying..."
      sleep(2)
      retry

    end
  end
end
