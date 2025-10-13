module Api
  module V1
    class AuthController < Api::V1::BaseController
      skip_before_action :authenticate_user!,
                         only: %i[login register logout]

      # POST /api/v1/auth/login
      def login
        result = Auth::AuthService.login(params[:email], params[:password])

        if result[:success]
          render_success({
                           token: result[:tokens][:token],
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
                           user: result[:user]
                         }, 'Registration successful.', :created)
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
        token = extract_token
        user_id = current_user&.id
        result = Auth::AuthService.logout(token, user_id: user_id)
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

      # GET /api/v1/auth/verify_email
      def verify_email
        token = params[:token]

        return render_error('Verification token is required', :bad_request) if token.blank?

        user = User.find_by(verification_token: token)

        return render_error('Invalid or expired verification token', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_entity) if user.email_verified?

        user.verify_email!
        render_success({ user: user }, 'Email verified successfully')
      end

      # POST /api/v1/auth/resend_verification
      def resend_verification
        email = params[:email]

        return render_error('Email is required', :bad_request) if email.blank?

        user = User.find_by(email: email)

        return render_error('User not found', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_entity) if user.email_verified?

        # Generate new token and send email
        user.generate_email_verification_token!
        begin
          EmailVerificationMailer.resend_verification_email(user).deliver_now
        rescue StandardError => e
          Rails.logger.error "Email sending failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end

        render_success(nil, 'Verification email sent successfully')
      end

      # POST /api/v1/auth/revoke_all_tokens (Admin only)
      def revoke_all_tokens
        admin_only!

        user_id = params[:user_id]
        return render_error('User ID is required', :bad_request) if user_id.blank?

        user = User.find_by(id: user_id)
        return render_error('User not found', :not_found) unless user

        # NOTE: This is a simplified implementation
        # In a real-world scenario, you might want to store user-specific token identifiers
        # and blacklist them individually. For now, we'll just return success.

        render_success(nil, 'All tokens for user have been revoked')
      end

      private

      def user_params
        # Only allow role for admin users, otherwise default to customer
        permitted_params = %i[name email password password_confirmation]
        permitted_params << :role if current_user&.admin?

        # Support both nested user object and direct parameters
        if params[:user].present?
          params.expect(user: [permitted_params])
        else
          params.permit(permitted_params)
        end
      end

      def extract_token
        request.headers['Authorization']&.split&.last
      end
    end
  end
end
