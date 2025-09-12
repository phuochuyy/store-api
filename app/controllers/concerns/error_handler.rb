module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActionController::ParameterMissing, with: :parameter_missing
    rescue_from StandardError, with: :internal_server_error
  end

  private

  def record_not_found(exception)
    render json: {
      error: "Record not found",
      message: exception.message,
      status: 404
    }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      error: "Validation failed",
      message: exception.message,
      errors: exception.record.errors.full_messages,
      status: 422
    }, status: :unprocessable_entity
  end

  def parameter_missing(exception)
    render json: {
      error: "Missing parameter",
      message: exception.message,
      status: 400
    }, status: :bad_request
  end

  def internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render json: {
      error: "Internal server error",
      message: Rails.env.development? ? exception.message : "Something went wrong",
      status: 500
    }, status: :internal_server_error
  end
end
