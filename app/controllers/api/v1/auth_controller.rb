class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :login, :register, :refresh_token ]

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = JWTEncodeService.encode(user)
      refresh_token = JWTEncodeService.encode_refresh_token(user)
      render json: {
        message: "Login successful",
        token: token,
        refresh_token: refresh_token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        }
      }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/register
  def register
    user = User.new(user_params)

    if user.save
      token = JWTEncodeService.encode(user)
      refresh_token = JWTEncodeService.encode_refresh_token(user)
      render json: {
        message: "Registration successful",
        token: token,
        refresh_token: refresh_token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        }
      }, status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/auth/refresh_token
  def refresh_token
    refresh_token = params[:refresh_token]

    if refresh_token.blank?
      return render json: { error: "Refresh token is required" }, status: :bad_request
    end

    payload = JWTDecodeService.decode_refresh_token(refresh_token)

    if payload.nil?
      return render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
    end

    user = User.find_by(id: payload["user_id"])

    if user.nil?
      return render json: { error: "User not found" }, status: :unauthorized
    end

    # Generate new tokens
    new_token = JWTEncodeService.encode(user)
    new_refresh_token = JWTEncodeService.encode_refresh_token(user)

    render json: {
      message: "Token refreshed successfully",
      token: new_token,
      refresh_token: new_refresh_token
    }
  end

  # POST /api/v1/auth/logout
  def logout
    # In a stateless JWT system, logout is typically handled client-side
    # by removing the token from storage. However, we can add token blacklisting
    # or other server-side logic here if needed.

    render json: { message: "Logged out successfully" }
  end

  # GET /api/v1/auth/me
  def me
    if current_user
      render json: {
        user: {
          id: current_user.id,
          name: current_user.name,
          email: current_user.email,
          role: current_user.role
        }
      }
    else
      render json: { error: "Not authenticated" }, status: :unauthorized
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end
end
