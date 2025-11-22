module Api
  module V1
    # rubocop:disable Metrics/ClassLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    class AuthController < Api::V1::BaseController
      skip_before_action :authenticate_user!,
                         only: %i[login register password_reset password_reset_confirm verify_email resend_verification
                                  refresh_token]

      def login
        email = params[:email]
        password = params[:password]

        # Basic validation (service will do more detailed validation)
        if email.blank? || password.blank?
          render json: {
            success: false,
            message: 'Email and password are required'
          }, status: :bad_request and return
        end

        # Check if email verification is required (can be configured via env or settings)
        require_email_verification = ENV.fetch('REQUIRE_EMAIL_VERIFICATION', 'false') == 'true'

        result = Auth::AuthService.login(
          email,
          password,
          device_id: device_id,
          ip_address: request.remote_ip,
          require_email_verification: require_email_verification
        )

        if result[:success]
          render_success({
                           token: result[:tokens][:token],
                           refresh_token: result[:tokens][:refresh_token],
                           user: result[:user]
                         }, 'Login successful')
        elsif result[:requires_verification]
          # Handle email verification requirement
          render json: {
            success: false,
            message: result[:message] || 'Email verification required',
            requires_verification: true
          }, status: :forbidden
        else
          # Generic error message for security (don't reveal if email exists)
          render json: {
            success: false,
            message: 'Invalid email or password'
          }, status: :unauthorized
        end
      end

      def register
        # Try to authenticate if token is provided (for admin role setting)
        if extract_token
          auth_result = Auth::TokenValidationService.authenticate(extract_token)
          @current_user = auth_result[:user] if auth_result[:success]
        end

        result = Auth::AuthService.register(
          user_params,
          device_id: device_id,
          ip_address: request.remote_ip
        )

        if result[:success]
          response_data = {
            token: result[:tokens][:token],
            refresh_token: result[:tokens][:refresh_token],
            user: result[:user]
          }

          # Include email verification info if needed
          if result[:email_verification_required]
            response_data[:email_verification_required] = true
            response_data[:message_detail] = result[:message_detail]
          end

          render_success(response_data, result[:message], :created)
        else
          render_error(result[:message], :unprocessable_content, result[:errors])
        end
      end

      def refresh_token
        # Allow refresh_token via params or Authorization header
        current_token = extract_token
        refresh_token_param = params[:refresh_token] || current_token

        # If we have a token in header, try to authenticate to get current_user
        # This allows us to get user_id for token rotation
        if current_token
          auth_result = Auth::TokenValidationService.authenticate(current_token)
          @current_user = auth_result[:user] if auth_result[:success]
        end

        result = Auth::AuthService.refresh_token(
          refresh_token_param,
          old_access_token: current_token,
          user_id: current_user&.id,
          device_id: device_id,
          ip_address: request.remote_ip
        )

        if result[:success]
          render_success(result[:tokens], result[:message])
        else
          status = result[:error].include?('required') ? :bad_request : :unauthorized
          render_error(result[:error], status)
        end
      end

      def logout
        token = extract_token
        user_id = current_user&.id
        result = Auth::AuthService.logout(token, user_id: user_id)
        render_success(nil, result[:message])
      end

      def me
        result = Auth::AuthService.get_current_user(current_user)

        if result[:success]
          render_success(result[:user], 'User retrieved successfully')
        else
          render_error(result[:error], :unauthorized)
        end
      end

      def verify_email
        token = params[:token]

        return render_error('Verification token is required', :bad_request) if token.blank?

        user = User.find_by(email_verification_token: token)

        return render_error('Invalid or expired verification token', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_content) if user.email_verified?

        user.verify_email!
        render_success({ user: user }, 'Email verified successfully')
      end

      def resend_verification
        email = params[:email]

        return render_error('Email is required', :bad_request) if email.blank?

        # Normalize email for lookup
        normalized_email = email.to_s.strip.downcase
        user = User.find_by(email: normalized_email)

        return render_error('User not found', :not_found) unless user

        return render_error('Email has already been verified', :unprocessable_content) if user.email_verified?

        user.generate_email_verification_token!
        begin
          EmailVerificationMailer.resend_verification_email(user).deliver_now
        rescue StandardError => e
          Rails.logger.error "Email sending failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end

        render_success(nil, 'Verification email sent successfully')
      end

      def revoke_all_tokens
        return render_error('Admin access required', :forbidden) unless current_user&.admin?

        user_id = params[:user_id]
        return render_error('User ID is required', :bad_request) if user_id.blank?

        user = User.find_by(id: user_id)
        return render_error('User not found', :not_found) unless user

        # Invalidate all tokens for user in cache
        Auth::Jwt::CacheService.invalidate_user_tokens(user.id)
        # Also blacklist all tokens in database
        Auth::Jwt::BlacklistService.blacklist_user_tokens(user.id, reason: 'Admin revoked all tokens')

        render_success(nil, 'All tokens for user have been revoked')
      end

      def password_reset
        email = params[:email]
        return render_error('Email is required', :bad_request) if email.blank?

        user = User.find_by(email: email)
        return render_error('User not found', :not_found) unless user

        # Generate password reset token
        token = PasswordResetToken.generate_for_user(user, ip_address: request.remote_ip,
                                                           user_agent: request.user_agent)

        # Send password reset email (implement email service)
        # PasswordResetMailer.send_reset_email(user, token).deliver_now

        render_success({ reset_token: token.token }, 'Password reset email sent successfully')
      end

      def password_reset_confirm
        token = params[:token]
        new_password = params[:new_password]
        password_confirmation = params[:password_confirmation]

        return render_error('Token is required', :bad_request) if token.blank?
        return render_error('New password is required', :bad_request) if new_password.blank?
        return render_error('Password confirmation is required', :bad_request) if password_confirmation.blank?
        return render_error('Passwords do not match', :bad_request) if new_password != password_confirmation

        reset_token = PasswordResetToken.find_by(token: token)
        return render_error('Invalid or expired reset token', :not_found) unless reset_token
        return render_error('Reset token has expired', :unprocessable_content) if reset_token.expired?

        user = reset_token.user
        user.password = new_password

        if user.save
          reset_token.destroy
          render_success(nil, 'Password reset successfully')
        else
          render_error('Failed to reset password', :unprocessable_content, user.errors.full_messages)
        end
      end

      def password_change
        current_password = params[:current_password]
        new_password = params[:new_password]
        password_confirmation = params[:password_confirmation]

        return render_error('Current password is required', :bad_request) if current_password.blank?
        return render_error('New password is required', :bad_request) if new_password.blank?
        return render_error('Password confirmation is required', :bad_request) if password_confirmation.blank?
        return render_error('Passwords do not match', :bad_request) if new_password != password_confirmation

        unless current_user.authenticate(current_password)
          return render_error('Current password is incorrect', :unauthorized)
        end

        current_user.password = new_password

        if current_user.save
          render_success(nil, 'Password changed successfully')
        else
          render_error('Failed to change password', :unprocessable_content, current_user.errors.full_messages)
        end
      end

      private

      def user_params
        permitted_params = %i[name first_name last_name email password password_confirmation]
        permitted_params << :role if current_user&.admin?
        if params[:user].present?
          params.expect(user: [permitted_params])
        else
          params.permit(permitted_params)
        end
      end

      def extract_token
        request.headers['Authorization']&.split&.last
      end

      # Generate or retrieve device ID from request
      # Device ID can be sent in X-Device-ID header or generated from User-Agent
      # Note: For better consistency, prefer using X-Device-ID header from client
      def device_id
        # First, try to get from header (preferred method)
        device_id = request.headers['X-Device-ID']
        return device_id if device_id.present?

        # If not provided, generate from User-Agent only (not IP, as IP can change)
        # This creates a more stable device fingerprint for mobile users
        user_agent = request.user_agent || 'unknown'
        # Use only User-Agent to avoid issues with IP changes (mobile networks, VPN)
        Digest::SHA256.hexdigest(user_agent)[0..31]
      end
    end
    # rubocop:enable Metrics/ClassLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
