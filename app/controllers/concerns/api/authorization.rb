module Api
  module Authorization
    extend ActiveSupport::Concern

    private

    def authorize!(resource, action)
      result = Auth::AuthenticationService.authorize(current_user, resource, action)

      return if result[:success]

      render json: {
        success: false,
        error: result[:error],
        status: :forbidden
      }, status: :forbidden
    end

    def admin_only!
      return if current_user&.admin?

      render json: {
        success: false,
        error: 'Admin access required',
        status: :forbidden
      }, status: :forbidden
    end
  end
end
