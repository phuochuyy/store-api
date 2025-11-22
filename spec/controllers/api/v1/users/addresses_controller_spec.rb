# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::Users::AddressesController, type: :controller do
  let(:user) { create(:user) }
  let(:address) { create(:user_address, user: user) }

  # Helper method to generate JWT token
  def generate_token(user)
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, secret_key, 'HS256')
  end

  let(:user_token) { generate_token(user) }

  before do
    request.headers['Content-Type'] = 'application/json'
    request.headers['Authorization'] = "Bearer #{user_token}"
  end

  describe 'GET #index' do
    before do
      address
      create(:user_address, user: user)
    end

    it 'returns user addresses' do
      allow(Users::AddressDataService).to receive(:get_user_addresses).and_return({
                                                                                    success: true,
                                                                                    addresses: [address],
                                                                                    total_count: 2
                                                                                  })

      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['addresses']).to be_an(Array)
    end

    it 'filters by address_type' do
      get :index, params: { address_type: 'shipping' }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end
  end

  describe 'GET #show' do
    it 'returns address details' do
      get :show, params: { id: address.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['address']).to be_present
      expect(json_response['data']['address']['id']).to eq(address.id)
    end

    context 'with non-existent address' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Address not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_address_params) do
      {
        address: {
          full_name: 'John Doe',
          address_line1: '123 Main St',
          city: 'New York',
          state: 'NY',
          postal_code: '10001',
          country: 'USA',
          phone: '1234567890',
          address_type: 'shipping'
        }
      }
    end

    it 'creates address successfully' do
      allow(Users::AddressCreationService).to receive(:create_address).and_return({
                                                                                    success: true,
                                                                                    address: address
                                                                                  })

      post :create, params: valid_address_params

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Address created successfully')
    end

    it 'returns error when creation fails' do
      allow(Users::AddressCreationService).to receive(:create_address).and_return({
                                                                                    success: false,
                                                                                    error: 'Creation failed',
                                                                                    errors: ['City is required']
                                                                                  })

      post :create, params: valid_address_params

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end

  describe 'PATCH #update' do
    it 'updates own address successfully' do
      allow(Users::AddressCreationService).to receive(:update_address).and_return({
                                                                                    success: true,
                                                                                    address: address
                                                                                  })

      patch :update, params: {
        id: address.id,
        address: {
          city: 'Los Angeles'
        }
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Address updated successfully')
    end

    it 'returns error when updating another user address' do
      other_user = create(:user)
      other_address = create(:user_address, user: other_user)

      patch :update, params: {
        id: other_address.id,
        address: { city: 'Updated' }
      }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only update your own addresses')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes own address successfully' do
      allow(Users::AddressCreationService).to receive(:delete_address).and_return({
                                                                                    success: true
                                                                                  })

      delete :destroy, params: { id: address.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Address deleted successfully')
    end

    it 'returns error when deleting another user address' do
      other_user = create(:user)
      other_address = create(:user_address, user: other_user)

      delete :destroy, params: { id: other_address.id }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only delete your own addresses')
    end
  end

  describe 'POST #set_default' do
    it 'sets address as default successfully' do
      allow(Users::AddressDataService).to receive(:update_default_address).and_return({
                                                                                        success: true
                                                                                      })

      post :set_default, params: { id: address.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Default address updated successfully')
    end

    it 'returns error when setting another user address as default' do
      other_user = create(:user)
      other_address = create(:user_address, user: other_user)

      post :set_default, params: { id: other_address.id }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only set your own addresses as default')
    end
  end

  describe 'GET #default' do
    it 'returns default address' do
      allow(Users::AddressDataService).to receive(:get_default_address).and_return({
                                                                                     success: true,
                                                                                     address: address
                                                                                   })

      get :default, params: { address_type: 'shipping' }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['address']).to be_present
    end

    it 'uses default address_type if not provided' do
      get :default

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
