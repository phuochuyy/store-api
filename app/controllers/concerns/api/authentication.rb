module Api
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
    end

    private

    def authenticate_user!
      token = extract_token
      return render_unauthorized('Token missing') unless token

      result = Auth::AuthenticationService.authenticate(token)
      return render_unauthorized(result[:error]) unless result[:success]

      @current_user = result[:user]
    end

    def current_user
      @current_user
    end

    def extract_token
      request.headers['Authorization']&.split&.last
    end

    def render_unauthorized(message)
      render json: {
        success: false,
        error: message,
        status: :unauthorized
      }, status: :unauthorized
    end
  end
end
