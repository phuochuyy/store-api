require 'rails_helper'

RSpec.describe Api::Authorization, type: :controller do
  # Create a test controller to test the concern
  controller(ApplicationController) do
    include Api::Authentication
    include Api::Authorization

    def test_authorize_action
      authorize!(test_resource, 'show')
      render json: { success: true }
    end

    def test_admin_only_action
      admin_only!
      render json: { success: true }
    end

    private

    def test_resource
      @test_resource ||= create(:user)
    end
  end

  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:valid_token) do
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
  let(:admin_token) do
    payload = {
      user_id: admin_user.id,
      email: admin_user.email,
      role: admin_user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end

  before do
    routes.draw do
      get 'test_authorize_action' => 'anonymous#test_authorize_action'
      get 'test_admin_only_action' => 'anonymous#test_admin_only_action'
    end
  end

  describe '#authorize!' do
    context 'with authorized user' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'allows access for resource owner' do
        # User can access their own resource
        allow(controller).to receive(:test_resource).and_return(user)

        get :test_authorize_action
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'with admin user' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'allows access for admin' do
        get :test_authorize_action
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'with unauthorized user' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'denies access for non-owner' do
        # User cannot access other user's resource
        other_user = create(:user)
        allow(controller).to receive(:test_resource).and_return(other_user)

        get :test_authorize_action
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'error' => 'Access denied',
          'status' => 'forbidden'
        )
      end
    end

    context 'with unauthenticated user' do
      it 'denies access' do
        get :test_authorize_action
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing policy' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'denies access when policy not found' do
        allow(controller).to receive(:test_resource).and_return('string_resource')

        get :test_authorize_action
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'error' => 'Authorization policy not found',
          'status' => 'forbidden'
        )
      end
    end
  end

  describe '#admin_only!' do
    context 'with admin user' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'allows access' do
        get :test_admin_only_action
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'with customer user' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'denies access' do
        get :test_admin_only_action
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'error' => 'Admin access required',
          'status' => 'forbidden'
        )
      end
    end

    context 'with unauthenticated user' do
      it 'denies access' do
        get :test_admin_only_action
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
