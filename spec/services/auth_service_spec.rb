require 'rails_helper'

RSpec.describe Auth::AuthService, type: :service do
  let(:user_params) do
    {
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      role: 'customer'
    }
  end

  let(:existing_user) do
    create(:user, email: 'existing@example.com', password: 'password123', password_confirmation: 'password123')
  end

  describe '.register' do
    context 'with valid parameters' do
      it 'creates a new user and returns success' do
        result = Auth::AuthService.register(user_params)

        expect(result[:success]).to be true
        expect(result[:user]).to be_present
        expect(result[:user][:email]).to eq('test@example.com')
        expect(result[:user][:name]).to eq('Test User')
        expect(result[:user][:role]).to eq('customer')
      end

      it 'creates user with admin role' do
        admin_params = user_params.merge(role: 'admin')
        result = Auth::AuthService.register(admin_params)

        expect(result[:success]).to be true
        expect(result[:user][:role]).to eq('admin')
      end

      it 'does not return password in user data' do
        result = Auth::AuthService.register(user_params)

        expect(result[:user][:password]).to be_nil
        expect(result[:user]).not_to have_key(:password_digest)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing email' do
        invalid_params = user_params.merge(email: '')
        result = Auth::AuthService.register(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:errors]).to be_present
      end

      it 'returns error for password mismatch' do
        invalid_params = user_params.merge(password_confirmation: 'different')
        result = Auth::AuthService.register(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns error for duplicate email' do
        create(:user, email: 'test@example.com')
        result = Auth::AuthService.register(user_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns error for invalid role' do
        invalid_params = user_params.merge(role: 'invalid_role')

        expect do
          Auth::AuthService.register(invalid_params)
        end.to raise_error(ArgumentError, "'invalid_role' is not a valid role")
      end
    end
  end

  describe '.login' do
    context 'with valid credentials' do
      it 'returns success and user data' do
        result = Auth::AuthService.login('existing@example.com', 'password123')

        expect(result[:success]).to be true
        expect(result[:user]).to be_present
        expect(result[:user][:email]).to eq(existing_user.email)
        expect(result[:user][:password]).to be_nil
      end
    end

    context 'with invalid credentials' do
      it 'returns error for wrong email' do
        result = Auth::AuthService.login('wrong@example.com', 'password123')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
      end

      it 'returns error for wrong password' do
        result = Auth::AuthService.login('existing@example.com', 'wrongpassword')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
      end

      it 'returns error for empty email' do
        result = Auth::AuthService.login('', 'password123')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
      end

      it 'returns error for empty password' do
        result = Auth::AuthService.login('existing@example.com', '')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
      end
    end
  end

  describe '.refresh_token' do
    let(:refresh_token) { JwtEncodeService.encode_refresh_token(existing_user) }

    context 'with valid refresh token' do
      it 'returns success and user data' do
        result = Auth::AuthService.refresh_token(refresh_token)

        expect(result[:success]).to be true
        expect(result[:user]).to be_present
        expect(result[:user][:email]).to eq(existing_user.email)
        expect(result[:user][:password]).to be_nil
      end
    end

    context 'with invalid refresh token' do
      it 'returns error for invalid token' do
        result = Auth::AuthService.refresh_token('invalid_token')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid or expired refresh token')
      end

      it 'returns error for expired token' do
        expired_token = JwtEncodeService.encode_refresh_token(existing_user, expiry: 1.second.ago)
        result = Auth::AuthService.refresh_token(expired_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid or expired refresh token')
      end

      it 'returns error for nil token' do
        result = Auth::AuthService.refresh_token(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Refresh token is required')
      end

      it 'returns error for empty token' do
        result = Auth::AuthService.refresh_token('')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Refresh token is required')
      end
    end
  end

  describe '.logout' do
    it 'returns success message' do
      result = Auth::AuthService.logout

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Logged out successfully')
    end
  end
end
