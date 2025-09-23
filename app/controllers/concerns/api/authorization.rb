module Api::Authorization
  extend ActiveSupport::Concern

  private

  def authorize!(resource, action)
    result = Auth::AuthenticationService.authorize(current_user, resource, action)
    
    unless result[:success]
      render json: { 
        success: false, 
        error: result[:error], 
        status: :forbidden 
      }, status: :forbidden
    end
  end

  def admin_only!
    unless current_user&.admin?
      render json: { 
        success: false, 
        error: "Admin access required", 
        status: :forbidden 
      }, status: :forbidden
    end
  end
end
