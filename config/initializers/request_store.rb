# frozen_string_literal: true

# RequestStore configuration
# Provides thread-local storage for request-scoped data
# See: https://github.com/steveklabnik/request_store

Rails.application.config.middleware.use RequestStore::Middleware

