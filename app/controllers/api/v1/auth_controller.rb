class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: %i[login register refresh_token]

  # POST /api/v1/auth/login
  def login
    result = Auth::AuthService.login(params[:email], params[:password])

    if result[:success]
      render_success({
                       token: result[:tokens][:token],
                       refresh_token: result[:tokens][:refresh_token],
                       user: result[:user]
                     }, result[:message])
    else
      render_error(result[:error], :unauthorized)
    end
  end

  # POST /api/v1/auth/register
  def register
    result = Auth::AuthService.register(user_params)

    if result[:success]
      render_success({
                       token: result[:tokens][:token],
                       refresh_token: result[:tokens][:refresh_token],
                       user: result[:user]
                     }, result[:message], :created)
    else
      render_error('Registration failed', :unprocessable_entity, result[:errors])
    end
  end

  # POST /api/v1/auth/refresh_token
  def refresh_token
    result = Auth::AuthService.refresh_token(params[:refresh_token])

    if result[:success]
      render_success(result[:tokens], result[:message])
    else
      status = result[:error].include?('required') ? :bad_request : :unauthorized
      render_error(result[:error], status)
    end
  end

  # POST /api/v1/auth/logout
  def logout
    result = Auth::AuthService.logout
    render_success(nil, result[:message])
  end

  # GET /api/v1/auth/me
  def me
    result = Auth::AuthService.get_current_user(current_user)

    if result[:success]
      render_success(result[:user], 'User retrieved successfully')
    else
      render_error(result[:error], :unauthorized)
    end
  end

  private

  def user_params
    # Only allow role for admin users, otherwise default to customer
    permitted_params = %i[name email password password_confirmation]
    permitted_params << :role if current_user&.admin?

    params.require(:user).permit(permitted_params)
  end
end
