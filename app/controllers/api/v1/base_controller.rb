class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Token missing" }, status: :unauthorized unless token

    validation_result = JwtDecodeService.validate_token(token)
    return render json: { error: validation_result[:error] }, status: :unauthorized unless validation_result[:valid]

    @current_user = validation_result[:user]
  end

  def current_user
    @current_user
  end

  def admin_only!
    render json: { error: "Admin access required" }, status: :forbidden unless current_user&.admin?
  end

  def record_not_found
    render json: { error: "Record not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
