class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!, except: [ :login, :register ]

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Token missing" }, status: :unauthorized unless token

    payload = User.decode_jwt(token)
    return render json: { error: "Invalid token" }, status: :unauthorized unless payload

    @current_user = User.find(payload["user_id"])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :unauthorized
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
