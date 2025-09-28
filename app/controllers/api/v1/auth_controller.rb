module Api
  module V1
    class AuthController < Api::V1::BaseController
      skip_before_action :authenticate_user!, only: %i[login register refresh_token verify_email resend_verification]

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
          # Send email verification
          EmailVerificationMailer.verification_email(result[:user]).deliver_now

          render_success({
                           token: result[:tokens][:token],
                           refresh_token: result[:tokens][:refresh_token],
                           user: result[:user]
                         }, 'Registration successful. Please check your email to verify your account.', :created)
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

      # GET /api/v1/auth/verify_email
      def verify_email
        token = params[:token]

        return render_error('Verification token is required', :bad_request) unless token.present?

        user = User.find_by_verification_token(token)

        return render_error('Invalid or expired verification token', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_entity) if user.email_verified?

        user.verify_email!
        render_success({ user: user }, 'Email verified successfully')
      end

      # POST /api/v1/auth/resend_verification
      def resend_verification
        email = params[:email]

        return render_error('Email is required', :bad_request) unless email.present?

        user = User.find_by_email(email)

        return render_error('User not found', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_entity) if user.email_verified?

        # Generate new token and send email
        user.generate_email_verification_token!
        EmailVerificationMailer.resend_verification_email(user).deliver_now

        render_success(nil, 'Verification email sent successfully')
      end

      private

      def user_params
        # Only allow role for admin users, otherwise default to customer
        permitted_params = %i[name email password password_confirmation]
        permitted_params << :role if current_user&.admin?

        params.expect(user: [permitted_params])
      end
    end
  end
end
