source 'https://rubygems.org'

# Core Rails
gem 'bootsnap', require: false
gem 'ostruct'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.0.2', '>= 8.0.2.1'
gem 'tzinfo-data', platforms: %i[windows jruby]

# Authentication
gem 'bcrypt', '~> 3.1.7'
gem 'jwt'
gem 'redis', '~> 5.0'

# API
gem 'active_model_serializers'
gem 'rack-cors'
gem 'rswag-api'
gem 'rswag-ui'

# Pagination
gem 'kaminari'

group :development, :test do
  # Debugging
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  # API Documentation
  gem 'rswag-specs'
  # Code Quality & Security
  gem 'brakeman', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  # Development Tools
  gem 'better_errors'               # Better error pages
  gem 'binding_of_caller'           # Better debugging
end

group :test do
  # Testing Framework
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
  # Test Coverage
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
  # API Testing
  gem 'rspec_junit_formatter'
  # Database Cleaner
  gem 'database_cleaner-active_record'
end
