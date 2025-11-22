# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::ProductComparisonsController, type: :controller do
  let(:user) { create(:user) }
  let(:product1) { create(:product) }
  let(:product2) { create(:product) }
  let(:product3) { create(:product) }
  let(:comparison) { create(:product_comparison, user: user) }

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
      comparison
      create(:product_comparison, user: user)
    end

    it 'returns user product comparisons' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['comparisons']).to be_an(Array)
      expect(json_response['data']['pagination']).to be_present
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['pagination']['per_page']).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns comparison details' do
      get :show, params: { id: comparison.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['comparison']).to be_present
      expect(json_response['data']['comparison']['id']).to eq(comparison.id)
    end

    context 'with non-existent comparison' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Product comparison not found')
      end
    end
  end

  describe 'POST #create' do
    it 'creates comparison with 2 products successfully' do
      post :create, params: {
        product_ids: [product1.id, product2.id]
      }

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Product comparison created successfully')
    end

    it 'creates comparison with maximum 5 products' do
      product4 = create(:product)
      product5 = create(:product)

      post :create, params: {
        product_ids: [product1.id, product2.id, product3.id, product4.id, product5.id]
      }

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'returns error when less than 2 products' do
      post :create, params: {
        product_ids: [product1.id]
      }

      expect(response).to have_http_status(:bad_request)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('At least 2 products are required for comparison')
    end

    it 'returns error when more than 5 products' do
      products = create_list(:product, 6)

      post :create, params: {
        product_ids: products.map(&:id)
      }

      expect(response).to have_http_status(:bad_request)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Maximum 5 products can be compared')
    end

    it 'returns error when product not found' do
      post :create, params: {
        product_ids: [product1.id, 999_999]
      }

      expect(response).to have_http_status(:not_found)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('One or more products not found')
    end
  end

  describe 'PATCH #update' do
    it 'updates own comparison successfully' do
      patch :update, params: {
        id: comparison.id,
        product_ids: [product1.id, product2.id, product3.id]
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'returns error when updating another user comparison' do
      other_user = create(:user)
      other_comparison = create(:product_comparison, user: other_user)

      patch :update, params: {
        id: other_comparison.id,
        product_ids: [product1.id, product2.id]
      }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only update your own comparisons')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes own comparison successfully' do
      delete :destroy, params: { id: comparison.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(ProductComparison.find_by(id: comparison.id)).to be_nil
    end

    it 'returns error when deleting another user comparison' do
      other_user = create(:user)
      other_comparison = create(:product_comparison, user: other_user)

      delete :destroy, params: { id: other_comparison.id }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only delete your own comparisons')
    end
  end
end
# rubocop:enable Metrics/BlockLength
