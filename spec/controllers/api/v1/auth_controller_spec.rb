require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :controller do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:valid_credentials) { { email: 'test@example.com', password: 'password123' } }
  let(:invalid_credentials) { { email: 'test@example.com', password: 'wrongpassword' } }

  before do
    request.headers['Content-Type'] = 'application/json'
  end

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns success with token' do
        post :login, params: valid_credentials

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Login successful'
        )
        expect(JSON.parse(response.body)['data']).to include('token', 'user')
      end

      it 'returns user information' do
        post :login, params: valid_credentials

        user_data = JSON.parse(response.body)['data']['user']
        expect(user_data).to include(
          'id' => user.id,
          'email' => user.email,
          'name' => user.name,
          'role' => user.role
        )
        expect(user_data).not_to include('password_digest')
      end

      it 'creates a valid JWT token' do
        post :login, params: valid_credentials

        token = JSON.parse(response.body)['data']['token']
        decoded_token = JWT.decode(token, Rails.application.secrets.secret_key_base, true, { algorithm: 'HS256' })

        expect(decoded_token[0]['user_id']).to eq(user.id)
        expect(decoded_token[0]['email']).to eq(user.email)
      end
    end

    context 'with invalid credentials' do
      it 'returns error for wrong password' do
        post :login, params: invalid_credentials

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid email or password'
        )
      end

      it 'returns error for non-existent email' do
        post :login, params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid email or password'
        )
      end

      it 'returns error for missing email' do
        post :login, params: { password: 'password123' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email and password are required'
        )
      end

      it 'returns error for missing password' do
        post :login, params: { email: 'test@example.com' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email and password are required'
        )
      end
    end
  end

  describe 'POST #register' do
    let(:valid_registration) do
      {
        name: 'New User',
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    context 'with valid registration data' do
      it 'creates a new user' do
        expect do
          post :register, params: valid_registration
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'User registered successfully'
        )
      end

      it 'returns user data without password' do
        post :register, params: valid_registration

        user_data = JSON.parse(response.body)['data']['user']
        expect(user_data).to include(
          'name' => 'New User',
          'email' => 'newuser@example.com',
          'role' => 'customer'
        )
        expect(user_data).not_to include('password', 'password_digest')
      end

      it 'sets default role to customer' do
        post :register, params: valid_registration

        user = User.find_by(email: 'newuser@example.com')
        expect(user.role).to eq('customer')
      end
    end

    context 'with invalid registration data' do
      it 'returns error for duplicate email' do
        post :register, params: valid_registration.merge(email: user.email)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for password mismatch' do
        post :register, params: valid_registration.merge(password_confirmation: 'different')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for missing required fields' do
        post :register, params: { email: 'test@example.com' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end
    end
  end

  describe 'POST #logout' do
    let(:token) { JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base) }

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'blacklists the token' do
        expect do
          post :logout
        end.to change(JwtBlacklistToken, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Logged out successfully'
        )
      end

      it 'prevents token reuse after logout' do
        post :logout

        # Try to use the same token again
        get :me
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        post :logout

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Token not provided'
        )
      end
    end
  end

  describe 'GET #me' do
    let(:token) { JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base) }

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'returns current user information' do
        get :me

        expect(response).to have_http_status(:ok)
        user_data = JSON.parse(response.body)['data']['user']
        expect(user_data).to include(
          'id' => user.id,
          'email' => user.email,
          'name' => user.name,
          'role' => user.role
        )
        expect(user_data).not_to include('password_digest')
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for malformed token' do
        request.headers['Authorization'] = 'Bearer invalid-token'
        get :me

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid token'
        )
      end

      it 'returns unauthorized for blacklisted token' do
        # First logout to blacklist the token
        post :logout

        # Then try to use it
        get :me
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        get :me

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Token not provided'
        )
      end
    end
  end

  describe 'POST #refresh_token' do
    let(:token) { JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base) }

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'returns new token' do
        post :refresh_token

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Token refreshed successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('token')
      end

      it 'blacklists old token' do
        expect do
          post :refresh_token
        end.to change(JwtBlacklistToken, :count).by(1)
      end
    end
  end

  describe 'POST #revoke_all_tokens' do
    let(:token) { JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base) }

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'revokes all user tokens' do
        # Create multiple tokens for the user
        token2 = JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base)
        token3 = JWT.encode({ user_id: user.id, email: user.email }, Rails.application.secrets.secret_key_base)

        post :revoke_all_tokens

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'All tokens revoked successfully'
        )

        # All tokens should be blacklisted
        expect(JwtBlacklistToken.blacklisted?(token.split('.').last)).to be true
      end
    end
  end
end
