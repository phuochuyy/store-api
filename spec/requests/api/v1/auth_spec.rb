require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:valid_user_params) do
    {
      name: 'Test User',
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password',
      role: 'customer'
    }
  end

  let(:admin_user_params) do
    {
      name: 'Admin User',
      email: 'admin@example.com',
      password: 'password',
      password_confirmation: 'password',
      role: 'admin'
    }
  end

  describe 'POST /api/v1/auth/register' do
    context 'with valid parameters' do
      it 'creates a new user and returns tokens' do
        expect do
          post '/api/v1/auth/register', params: valid_user_params
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']).to include('token', 'refresh_token', 'user')
        expect(json_response['data']['user']['email']).to eq('test@example.com')
        expect(json_response['data']['user']['role']).to eq('customer')
      end

      it 'creates admin user with admin role' do
        post '/api/v1/auth/register', params: admin_user_params

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['data']['user']['role']).to eq('admin')
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors for missing email' do
        invalid_params = valid_user_params.merge(email: '')
        post '/api/v1/auth/register', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Registration failed')
      end

      it 'returns validation errors for password mismatch' do
        invalid_params = valid_user_params.merge(password_confirmation: 'different')
        post '/api/v1/auth/register', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end

      it 'returns validation errors for duplicate email' do
        create(:user, email: 'test@example.com')
        post '/api/v1/auth/register', params: valid_user_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST /api/v1/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password', password_confirmation: 'password') }

    context 'with valid credentials' do
      it 'returns tokens and user information' do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']).to include('token', 'refresh_token', 'user')
        expect(json_response['data']['user']['email']).to eq('test@example.com')
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrongpassword' }

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for non-existent email' do
        post '/api/v1/auth/login', params: { email: 'nonexistent@example.com', password: 'password' }

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST /api/v1/auth/refresh_token' do
    let!(:user) { create(:user) }
    let(:refresh_token) { JwtEncodeService.encode_refresh_token(user) }

    context 'with valid refresh token' do
      it 'returns new tokens' do
        post '/api/v1/auth/refresh_token', params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']).to include('token', 'refresh_token')
      end
    end

    context 'with invalid refresh token' do
      it 'returns unauthorized for invalid token' do
        post '/api/v1/auth/refresh_token', params: { refresh_token: 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end

      it 'returns bad request for missing token' do
        post '/api/v1/auth/refresh_token', params: {}

        expect(response).to have_http_status(:bad_request)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'GET /api/v1/auth/me' do
    let!(:user) { create(:user) }
    let(:token) { JwtEncodeService.encode(user) }

    context 'with valid token' do
      it 'returns current user information' do
        get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']['email']).to eq(user.email)
        expect(json_response['data']['name']).to eq(user.name)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        get '/api/v1/auth/me'

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized' do
        get '/api/v1/auth/me', headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST /api/v1/auth/logout' do
    let!(:user) { create(:user) }
    let(:token) { JwtEncodeService.encode(user) }

    context 'with valid token' do
      it 'returns success message' do
        post '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Logged out successfully')
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        post '/api/v1/auth/logout'

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end
end
