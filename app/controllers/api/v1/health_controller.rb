module Api
  module V1
    class HealthController < ApplicationController
      include Api::ErrorHandling
      include Common::Pagination
      include Common::Filtering

      before_action :set_default_response_format

      # GET /api/v1/health
      def index
        render json: {
          status: 'ok',
          message: 'Phone Store API is running',
          version: '1.0.0',
          timestamp: Time.current.iso8601,
          database: database_status
        }
      end

      private

      def set_default_response_format
        request.format = :json
        response.headers['Content-Type'] = 'application/json'
      end

      def database_status
        # Try to execute a simple query to check database connectivity
        ActiveRecord::Base.connection.execute('SELECT 1')
        'connected'
      rescue StandardError => e
        Rails.logger.error "Database connection error: #{e.message}"
        'disconnected'
      end
    end
  end
end
