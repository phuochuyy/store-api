source "https://rubygems.org"

# Core Rails
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# Authentication
gem "bcrypt", "~> 3.1.7"
gem "jwt"

# API
gem "rack-cors"
gem "rswag-api"
gem "rswag-ui"
gem "active_model_serializers"

# Pagination
gem "kaminari"

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  # API Documentation
  gem "rswag-specs"
end

group :development do
  # Development Tools
  gem "better_errors"               # Better error pages
  gem "binding_of_caller"           # Better debugging
end

group :test do
  # Testing Framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  # Test Coverage
  gem "simplecov", require: false
  gem "simplecov-lcov", require: false
  # API Testing
  gem "rspec_junit_formatter"
  # Database Cleaner
  gem "database_cleaner-active_record"
end
