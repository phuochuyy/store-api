require 'rails_helper'

RSpec.describe Api::Authentication, type: :controller do
  # Create a test controller to test the concern
  controller(ApplicationController) do
    include Api::Authentication

    def test_action
      render json: { current_user: current_user&.id }
    end
  end

  let(:user) { create(:user) }
  let(:valid_token) do
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
  end

  before do
    routes.draw do
      get 'test_action' => 'anonymous#test_action'
    end
  end

  describe 'before_action :authenticate_user!' do
    context 'with valid token' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'sets current_user' do
        get :test_action
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['current_user']).to eq(user.id)
      end
    end

    context 'with invalid token' do
      before do
        request.headers['Authorization'] = 'Bearer invalid-token'
      end

      it 'returns unauthorized' do
        get :test_action
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['success']).to be false
        expect(response.parsed_body['message']).to be_present
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: 2.days.ago.to_i,
          exp: 1.day.ago.to_i
        }
        JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
      end

      before do
        request.headers['Authorization'] = "Bearer #{expired_token}"
      end

      it 'returns unauthorized' do
        get :test_action
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['success']).to be false
        expect(response.parsed_body['message']).to be_present
      end
    end

    context 'with blacklisted token' do
      before do
        Auth::Jwt::BlacklistService.blacklist_token(valid_token)
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns unauthorized' do
        get :test_action
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['success']).to be false
        expect(response.parsed_body['message']).to be_present
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        get :test_action
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to include('success' => false, 'message' => 'Token missing')
      end
    end

    context 'with malformed authorization header' do
      before do
        request.headers['Authorization'] = 'InvalidFormat'
      end

      it 'returns unauthorized' do
        get :test_action
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to include('success' => false, 'message' => 'Token missing')
      end
    end
  end

  describe '#current_user' do
    before do
      request.headers['Authorization'] = "Bearer #{valid_token}"
    end

    it 'returns the authenticated user' do
      get :test_action
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['current_user']).to eq(user.id)
    end
  end

  describe '#extract_token' do
    it 'extracts token from Authorization header' do
      request.headers['Authorization'] = "Bearer #{valid_token}"
      token = controller.send(:extract_token)
      expect(token).to eq(valid_token)
    end

    it 'returns nil for malformed header' do
      request.headers['Authorization'] = 'InvalidFormat'
      token = controller.send(:extract_token)
      expect(token).to be_nil
    end

    it 'returns nil for missing header' do
      token = controller.send(:extract_token)
      expect(token).to be_nil
    end
  end

  describe 'unauthorized response format' do
    it 'returns success false and message in body' do
      get :test_action
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['success']).to be false
      expect(response.parsed_body['message']).to eq('Token missing')
    end
  end
end
