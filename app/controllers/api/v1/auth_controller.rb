class Api::V1::AuthController < Api::V1::BaseController
  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = user.generate_jwt
      render json: {
        message: "Login successful",
        token: token,
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
      token = user.generate_jwt
      render json: {
        message: "Registration successful",
        token: token,
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
