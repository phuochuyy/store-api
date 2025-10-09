module Auth
  class AuthService
    class << self
      def login(email, password)
        user = User.find_by(email: email)

        return { success: false, error: 'Invalid email or password' } unless user&.authenticate(password)

        tokens = generate_tokens(user)
        user_data = UserSerializer.new(user).as_json

        {
          success: true,
          message: 'Login successful',
          tokens: tokens,
          user: user_data
        }
      end

      def register(user_params)
        user = User.new(user_params)

        if user.save
          tokens = generate_tokens(user)
          user_data = UserSerializer.new(user).as_json

          {
            success: true,
            message: 'Registration successful',
            tokens: tokens,
            user: user_data
          }
        else
          {
            success: false,
            errors: user.errors.full_messages
          }
        end
      end

      def refresh_token(refresh_token_param)
        return { success: false, error: 'Refresh token is required' } if refresh_token_param.blank?

        payload = JwtDecodeService.decode_refresh_token(refresh_token_param)
        return { success: false, error: 'Invalid or expired refresh token' } unless payload

        user = User.find_by(id: payload['user_id'])
        return { success: false, error: 'User not found' } unless user

        tokens = generate_tokens(user)

        {
          success: true,
          message: 'Token refreshed successfully',
          tokens: tokens
        }
      end

      def logout(token = nil, user_id: nil)
        # Blacklist the current token if provided
        if token.present?
          JwtBlacklistService.blacklist_token(
            token,
            user_id: user_id,
            token_type: 'access',
            reason: 'User logout'
          )
        end

        { success: true, message: 'Logged out successfully' }
      end

      def get_current_user(user)
        return { success: false, error: 'Not authenticated' } unless user

        user_data = UserSerializer.new(user).as_json

        {
          success: true,
          user: user_data
        }
      end

      private

      def generate_tokens(user)
        {
          token: JwtEncodeService.encode(user),
          refresh_token: JwtEncodeService.encode_refresh_token(user)
        }
      end
    end
  end
end
