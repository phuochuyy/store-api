# frozen_string_literal: true

module ErrorHandling
  extend ActiveSupport::Concern

  # rescue_from handlers are matched from the LAST declared to the first, so the catch-all
  # StandardError handler must come first; otherwise it shadows every specific handler below.
  included do
    rescue_from StandardError, with: :internal_server_error
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActionController::ParameterMissing, with: :parameter_missing
  end

  private

  # The exception message contains the SQL conditions, so it is not echoed to the client.
  def record_not_found(exception)
    render_error("#{exception.model || 'Record'} not found", :not_found)
  end

  def record_invalid(exception)
    render_error('Validation failed', :unprocessable_content, exception.record.errors.full_messages)
  end

  def parameter_missing(exception)
    render_error('Missing parameter', :bad_request, exception.message)
  end

  def internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    message = Rails.env.local? ? exception.message : 'Something went wrong'
    render_error(message, :internal_server_error)
  end

end
