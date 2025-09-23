module Api::ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActionController::ParameterMissing, with: :parameter_missing
    rescue_from StandardError, with: :internal_server_error
  end

  private

  def record_not_found(exception)
    render_error("Record not found", :not_found, [exception.message])
  end

  def record_invalid(exception)
    render_error("Validation failed", :unprocessable_entity, exception.record.errors.full_messages)
  end

  def parameter_missing(exception)
    render_error("Missing required parameter", :bad_request, [exception.message])
  end

  def internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    message = Rails.env.development? ? exception.message : "Something went wrong"
    render_error(message, :internal_server_error)
  end
end
