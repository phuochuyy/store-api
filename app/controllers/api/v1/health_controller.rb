module Api
  module V1
    class HealthController < ApplicationController
      # Remove duplicate includes - ErrorHandling already in ApplicationController
      # Remove duplicate set_default_response_format - already in ApplicationController

      def index
        render json: {
          status: 'ok',
          message: 'Phone Store API is running',
          version: 'v1',
          timestamp: Time.current.iso8601,
          environment: Rails.env,
          database: database_status
        }
      end

      private

      def database_status
        # Try to execute a simple query to check database connectivity
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.execute('SELECT 1')
        end
        'connected'
      rescue StandardError => e
        Rails.logger.error "Database connection error: #{e.message}"
        'disconnected'
      end
    end
  end
end
