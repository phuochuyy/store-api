class ApplicationController < ActionController::API
  include ErrorHandler

  # Simple authentication for demo API
  before_action :authenticate_user!, except: [ :login, :authenticate ]

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Token missing" }, status: :unauthorized unless token

    validation_result = JWTDecodeService.validate_token(token)
    return render json: { error: validation_result[:error] }, status: :unauthorized unless validation_result[:valid]

    @current_user = validation_result[:user]
  end

  def current_user
    @current_user
  end

  def admin_only!
    unless current_user&.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end
end
