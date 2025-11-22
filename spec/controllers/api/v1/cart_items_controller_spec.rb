# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::CartItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:product) { create(:product, stock_quantity: 10, price: 99.99) }
  let(:product2) { create(:product, stock_quantity: 5, price: 49.99) }
  let(:session_id) { SecureRandom.uuid }
  let(:cart) { create(:cart, user: user, session_id: session_id) }
  let(:cart_item) { create(:cart_item, cart: cart, product: product, quantity: 2) }
  let(:token) do
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

  before do
    request.headers['Content-Type'] = 'application/json'
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Session-ID'] = session_id
  end

  describe 'GET #index' do
    before do
      cart_item
      create(:cart_item, cart: cart, product: product2, quantity: 1)
    end

    it 'returns all cart items' do
      get :index, params: { cart_id: cart.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['cart_items'].count).to eq(2)
      expect(json_response['data']).to include('total_items', 'total_amount')
    end
  end

  describe 'GET #show' do
    it 'returns cart item details' do
      get :show, params: { cart_id: cart.id, id: cart_item.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['cart_item']['id']).to eq(cart_item.id)
      expect(json_response['data']['product']).to be_present
    end

    context 'with non-existent cart item' do
      it 'returns not found' do
        get :show, params: { cart_id: cart.id, id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Cart item not found')
      end
    end
  end

  describe 'POST #create' do
    context 'with valid product and quantity' do
      it 'adds product to cart' do
        post :create, params: {
          cart_id: cart.id,
          cart_item: { product_id: product.id, quantity: 2 }
        }

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(cart.reload.cart_items.count).to eq(1)
        expect(cart.cart_items.first.quantity).to eq(2)
      end

      it 'defaults quantity to 1 if not specified' do
        post :create, params: {
          cart_id: cart.id,
          cart_item: { product_id: product.id }
        }

        expect(response).to have_http_status(:created)
        expect(cart.reload.cart_items.first.quantity).to eq(1)
      end
    end

    context 'with out of stock product' do
      let(:out_of_stock_product) { create(:product, stock_quantity: 0) }

      it 'returns error' do
        post :create, params: {
          cart_id: cart.id,
          cart_item: { product_id: out_of_stock_product.id, quantity: 1 }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Product is out of stock')
      end
    end

    context 'with quantity exceeding stock' do
      it 'returns error' do
        post :create, params: {
          cart_id: cart.id,
          cart_item: { product_id: product.id, quantity: 15 }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to include('Only')
      end
    end

    context 'with non-existent product' do
      it 'returns error' do
        post :create, params: {
          cart_id: cart.id,
          cart_item: { product_id: 999_999, quantity: 1 }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid quantity' do
      it 'updates cart item quantity' do
        patch :update, params: {
          cart_id: cart.id,
          id: cart_item.id,
          cart_item: { quantity: 5 }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(cart_item.reload.quantity).to eq(5)
      end
    end

    context 'with quantity exceeding stock' do
      it 'returns error' do
        patch :update, params: {
          cart_id: cart.id,
          id: cart_item.id,
          cart_item: { quantity: 15 }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'with out of stock product' do
      let(:out_of_stock_product) { create(:product, stock_quantity: 0) }
      let(:cart_item_out_of_stock) { create(:cart_item, cart: cart, product: out_of_stock_product) }

      it 'returns error' do
        patch :update, params: {
          cart_id: cart.id,
          id: cart_item_out_of_stock.id,
          cart_item: { quantity: 1 }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'removes cart item from cart' do
      cart_item # create cart item
      delete :destroy, params: { cart_id: cart.id, id: cart_item.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(cart.reload.cart_items.count).to eq(0)
    end
  end
end
# rubocop:enable Metrics/BlockLength
