# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::ProductWishlistsController, type: :controller do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:wishlist) { create(:product_wishlist, user: user, product: product) }

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
      wishlist
      create(:product_wishlist, user: user)
    end

    it 'returns user wishlist' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['wishlists']).to be_an(Array)
      expect(json_response['data']['wishlists'].length).to eq(2)
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
    it 'returns wishlist item details' do
      get :show, params: { id: wishlist.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['wishlist']).to be_present
      expect(json_response['data']['wishlist']['id']).to eq(wishlist.id)
    end

    context 'with non-existent wishlist' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Wishlist item not found')
      end
    end
  end

  describe 'POST #create' do
    let(:new_product) { create(:product) }

    it 'adds product to wishlist successfully' do
      post :create, params: { product_id: new_product.id }

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Product added to wishlist successfully')
      expect(json_response['data']['wishlist']).to be_present
    end

    it 'returns error when product not found' do
      post :create, params: { product_id: 999_999 }

      expect(response).to have_http_status(:not_found)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Product not found')
    end

    it 'returns error when product already in wishlist' do
      post :create, params: { product_id: product.id }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Product already in wishlist')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes product from wishlist successfully' do
      delete :destroy, params: { id: wishlist.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Product removed from wishlist successfully')
      expect(ProductWishlist.find_by(id: wishlist.id)).to be_nil
    end

    it 'returns error when removing another user wishlist item' do
      other_user = create(:user)
      other_wishlist = create(:product_wishlist, user: other_user)

      delete :destroy, params: { id: other_wishlist.id }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only remove your own wishlist items')
    end
  end

  describe 'GET #my_wishlist' do
    before do
      wishlist
      create(:product_wishlist, user: user)
    end

    it 'returns user wishlist' do
      get :my_wishlist

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['wishlists']).to be_an(Array)
      expect(json_response['data']['total_count']).to eq(2)
    end
  end
end
# rubocop:enable Metrics/BlockLength
