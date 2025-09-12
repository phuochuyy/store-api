class Api::V1::HealthController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :index ]

  # GET /api/v1/health
  def index
    render json: {
      status: "ok",
      message: "Phone Store API is running",
      version: "1.0.0",
      timestamp: Time.current.iso8601,
      database: database_status
    }
  end

  private

  def database_status
    ActiveRecord::Base.connection.active? ? "connected" : "disconnected"
  rescue => e
    "error: #{e.message}"
  end
end
