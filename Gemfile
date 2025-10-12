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

# API
gem 'active_model_serializers'
gem 'rack-cors'
gem 'rswag-api'
gem 'rswag-ui'

# Pagination
gem 'kaminari'

group :development do
  # Debugging
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  # API Documentation
  gem 'rswag-specs'
  # Code Quality & Security
  gem 'brakeman', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  # Development Tools
  gem 'better_errors'               # Better error pages
  gem 'binding_of_caller'           # Better debugging
end

