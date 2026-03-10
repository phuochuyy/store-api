require 'digest'

module Auth
  # User authentication service: login, register, refresh_token, logout, get_current_user.
  # Integrates JWT (encode, blacklist, cache) and optional email verification.
  class AuthService
    class << self
      # Login: find user by email (case-insensitive), verify password and optional email_verified; return tokens + user.
      def login(email, password, device_id: nil, ip_address: nil, require_email_verification: false)
        normalized_email = email.to_s.strip.downcase
        return { success: false, error: 'Email is required' } if normalized_email.blank?
        return { success: false, error: 'Password is required' } if password.blank?

        user = User.find_by(email: normalized_email)

        unless user
          Rails.logger.warn "Failed login attempt for email: #{normalized_email} " \
                            "(user not found) from IP: #{ip_address}"
          return { success: false, error: 'Invalid email or password' }
        end

        unless user.authenticate(password)
          Rails.logger.warn "Failed login attempt for user: #{user.id} (wrong password) from IP: #{ip_address}"
          return { success: false, error: 'Invalid email or password' }
        end

        if require_email_verification && !user.email_verified?
          Rails.logger.info "Login blocked for user: #{user.id} (email not verified)"
          return {
            success: false,
            error: 'Email not verified',
            requires_verification: true,
            message: 'Please verify your email before logging in'
          }
        end

        Rails.logger.info "Successful login for user: #{user.id} (#{user.email}) from IP: #{ip_address}"

        tokens = generate_tokens(user, device_id: device_id, ip_address: ip_address)
        user_data = UserSerializer.new(user).as_json

        {
          success: true,
          message: 'Login successful',
          tokens: tokens,
          user: user_data
        }
      end

      # Register new user from user_params; send verification email if configured; return tokens + user (+ email_verification_required if unverified).
      def register(user_params, device_id: nil, ip_address: nil)
        user_params[:email] = user_params[:email].to_s.strip.downcase if user_params[:email].present?

        user = User.new(user_params)

        if user.save
          Rails.logger.info "New user registered: #{user.id} (#{user.email}) from IP: #{ip_address}"

          begin
            EmailVerificationMailer.verification_email(user).deliver_later if user.email_verification_token.present?
          rescue StandardError => e
            Rails.logger.error "Failed to send verification email: #{e.message}"
          end

          tokens = generate_tokens(user, device_id: device_id, ip_address: ip_address)
          user_data = UserSerializer.new(user).as_json

          {
            success: true,
            message: 'User registered successfully',
            tokens: tokens,
            user: user_data,
            email_verification_required: !user.email_verified?,
            message_detail: user.email_verified? ? nil : 'Please check your email to verify your account'
          }
        else
          Rails.logger.warn "Registration failed for email: #{user_params[:email]} " \
                            "from IP: #{ip_address} - Errors: #{user.errors.full_messages.join(', ')}"

          {
            success: false,
            message: 'Validation failed',
            errors: user.errors.full_messages
          }
        end
      end

      # Refresh token: decode refresh_token, find user, blacklist old token (rotation), issue new tokens.
      def refresh_token(refresh_token_param, old_access_token: nil, user_id: nil, device_id: nil, ip_address: nil)
        return { success: false, error: 'Refresh token is required' } if refresh_token_param.blank?

        payload = Auth::Jwt::DecodeService.decode_refresh_token(refresh_token_param)

        payload = Auth::Jwt::DecodeService.decode(refresh_token_param) if payload.nil?

        return { success: false, error: 'Invalid or expired refresh token' } unless payload

        user = User.find_by(id: payload['user_id'])
        return { success: false, error: 'User not found' } unless user

        if payload['device_id'].present? && device_id.present? && payload['device_id'] != device_id
          Rails.logger.warn "Device mismatch for user #{user.id}: " \
                            "token has #{payload['device_id']}, request has #{device_id}"
          return { success: false, error: 'Device mismatch' }
        end

        # Validate IP hash if present in token
        # Note: IP validation is lenient - IP can change (mobile, VPN) so we only warn
        # but don't block. This prevents false positives while still detecting suspicious activity.
        if payload['ip_hash'].present? && ip_address.present?
          expected_ip_hash = Digest::SHA256.hexdigest(ip_address.to_s)[0..15]
          unless payload['ip_hash'] == expected_ip_hash
            Rails.logger.warn "IP mismatch for user #{user.id}: " \
                              "token has #{payload['ip_hash']}, request has #{expected_ip_hash}"
            # Don't block - IP can change legitimately (mobile, VPN, etc.)
            # But log for security monitoring
          end
        end

        # TOKEN ROTATION: Blacklist the old refresh token (security best practice)
        # Check if already blacklisted to avoid errors on concurrent requests
        unless Auth::Jwt::BlacklistService.blacklisted?(refresh_token_param)
          Auth::Jwt::BlacklistService.blacklist_token(
            refresh_token_param,
            user_id: user_id,
            token_type: 'refresh',
            reason: 'Token rotation'
          )
        end

        # Blacklist old access token if provided
        if old_access_token.present?
          Auth::Jwt::BlacklistService.blacklist_token(
            old_access_token,
            user_id: user_id,
            token_type: 'access',
            reason: 'Token refresh'
          )
        end

        # Generate new tokens with same device_id and ip_address from refresh token
        tokens = generate_tokens(
          user,
          device_id: device_id || payload['device_id'],
          ip_address: ip_address
        )

        {
          success: true,
          message: 'Token refreshed successfully',
          tokens: tokens
        }
      end

      # Logout: blacklist current token and (if user_id or decoded from token) all tokens for that user.
      def logout(token = nil, user_id: nil)
        # If user_id is provided, blacklist all tokens for the user
        # This is more secure as it invalidates all sessions
        if user_id.present?
          # Blacklist all user tokens (sets logout timestamp)
          Auth::Jwt::BlacklistService.blacklist_user_tokens(
            user_id,
            reason: 'User logout'
          )
          # Also blacklist the current token if provided (for database record)
          if token.present?
            Auth::Jwt::BlacklistService.blacklist_token(
              token,
              user_id: user_id,
              token_type: 'access',
              reason: 'User logout'
            )
          end
        # Otherwise, try to extract user_id from token
        elsif token.present?
          # Try to extract user_id from token if not provided
          payload = Auth::Jwt::DecodeService.decode_raw(token)
          extracted_user_id = payload&.dig('user_id')

          if extracted_user_id.present?
            # Blacklist all tokens for better security
            Auth::Jwt::BlacklistService.blacklist_user_tokens(
              extracted_user_id,
              reason: 'User logout'
            )
            # Also blacklist the current token (for database record)
            Auth::Jwt::BlacklistService.blacklist_token(
              token,
              user_id: extracted_user_id,
              token_type: 'access',
              reason: 'User logout'
            )
          else
            # Fallback: just blacklist the current token
            Auth::Jwt::BlacklistService.blacklist_token(
              token,
              user_id: user_id,
              token_type: 'access',
              reason: 'User logout'
            )
          end
        end

        { success: true, message: 'Logged out successfully' }
      end

      # Return serialized user data for API (auth/me); returns error if user nil.
      def get_current_user(user)
        return { success: false, error: 'Not authenticated' } unless user

        user_data = UserSerializer.new(user).as_json

        {
          success: true,
          user: user_data
        }
      end

      private

      def generate_tokens(user, device_id: nil, ip_address: nil)
        access_token = Auth::Jwt::EncodeService.encode(user, device_id: device_id, ip_address: ip_address)
        refresh_token = Auth::Jwt::EncodeService.encode_refresh_token(user, device_id: device_id,
                                                                            ip_address: ip_address)

        # Track tokens for user (for revoke all functionality)
        Auth::Jwt::CacheService.track_user_token(user.id, access_token)
        Auth::Jwt::CacheService.track_user_token(user.id, refresh_token)

        {
          token: access_token,
          refresh_token: refresh_token
        }
      end
    end
  end
end
