class Api::BaseController < ApplicationController
  include Api::Authentication
  include Api::ErrorHandling
  include Common::Pagination
  include Common::Filtering

  before_action :authenticate_user!
  before_action :set_default_response_format

  private

  def set_default_response_format
    request.format = :json
  end

  def render_success(data = nil, message = nil, status = :ok)
    response_data = { success: true }
    response_data[:data] = data if data
    response_data[:message] = message if message
    render json: response_data, status: status
  end

  def render_error(message, status = :bad_request, errors = nil)
    response_data = { 
      success: false, 
      error: message,
      status: status
    }
    response_data[:errors] = errors if errors
    render json: response_data, status: status
  end
end
