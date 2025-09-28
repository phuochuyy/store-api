require 'rails_helper'

RSpec.describe 'Api::V1::Carts', type: :request do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 100.0) }
  let(:cart) { create(:cart, user: user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.generate_jwt}" } }

  describe 'GET /api/v1/carts' do
    context 'when user is authenticated' do
      it 'returns user cart' do
        get '/api/v1/carts', headers: headers

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']).to include('cart', 'cart_items', 'total_items', 'total_amount')
      end

      it 'creates new cart if none exists' do
        expect do
          get '/api/v1/carts', headers: headers
        end.to change(Cart, :count).by(1)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/carts'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/carts/:id' do
    context 'when cart exists' do
      it 'returns cart details' do
        get "/api/v1/carts/#{cart.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']['cart']['id']).to eq(cart.id)
      end
    end

    context 'when cart does not exist' do
      it 'returns not found' do
        get '/api/v1/carts/999', headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/carts' do
    it 'creates new cart' do
      expect do
        post '/api/v1/carts', headers: headers
      end.to change(Cart, :count).by(1)

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['data']).to include('cart', 'cart_items')
    end
  end

  describe 'PUT /api/v1/carts/:id' do
    it 'updates cart status' do
      put "/api/v1/carts/#{cart.id}",
          params: { cart: { status: 'abandoned' } },
          headers: headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(cart.reload.status).to eq('abandoned')
    end
  end

  describe 'DELETE /api/v1/carts/:id' do
    it 'deletes cart' do
      expect do
        delete "/api/v1/carts/#{cart.id}", headers: headers
      end.to change(Cart, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/carts/:id/clear' do
    let!(:cart_item) { create(:cart_item, cart: cart, product: product) }

    it 'clears all items from cart' do
      delete "/api/v1/carts/#{cart.id}/clear", headers: headers

      expect(response).to have_http_status(:ok)
      expect(cart.reload.cart_items.count).to eq(0)
    end
  end

  describe 'POST /api/v1/carts/merge' do
    let(:guest_cart) { create(:cart, :guest_cart) }
    let!(:guest_cart_item) { create(:cart_item, cart: guest_cart, product: product) }

    it 'merges guest cart with user cart' do
      post '/api/v1/carts/merge',
           params: { guest_session_id: guest_cart.session_id },
           headers: headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(guest_cart.reload.status).to eq('abandoned')
    end

    it 'returns error if guest session ID is missing' do
      post '/api/v1/carts/merge', headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
