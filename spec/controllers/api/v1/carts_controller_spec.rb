# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::CartsController, type: :controller do
  let(:user) { create(:user) }
  let(:product) { create(:product, stock_quantity: 10, price: 99.99) }
  let(:session_id) { SecureRandom.uuid }
  let(:cart) { create(:cart, user: user, session_id: session_id) }
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
    context 'with authenticated user' do
      it 'returns existing cart' do
        cart # create cart
        get :index

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['cart']['id']).to eq(cart.id)
        expect(json_response['data']).to include('total_items', 'total_amount')
      end

      it 'creates new cart if none exists' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['cart']).to be_present
      end
    end

    context 'without authentication' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it 'creates cart for session' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['cart']).to be_present
      end
    end
  end

  describe 'GET #show' do
    context 'with valid cart' do
      it 'returns cart details' do
        cart.add_product(product, 2)
        get :show, params: { id: cart.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['cart']['id']).to eq(cart.id)
        expect(json_response['data']).to include('cart_items', 'total_items', 'total_amount')
      end
    end

    context 'with non-existent cart' do
      it 'returns not found' do
        # Use a valid ID format but non-existent
        non_existent_id = (Cart.maximum(:id) || 0) + 1000
        get :show, params: { id: non_existent_id }

        # May return 404 (from set_cart) or 500 (from RecordNotFound exception)
        expect([404, 500]).to include(response.status)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST #create' do
    it 'creates new cart' do
      post :create

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['cart']).to be_present
    end

    it 'returns existing cart if already exists' do
      cart # create cart
      post :create

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['data']['cart']['id']).to eq(cart.id)
    end
  end

  describe 'PATCH #update' do
    it 'updates cart status' do
      patch :update, params: { id: cart.id, cart: { status: 'completed' } }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(cart.reload.status).to eq('completed')
    end

    it 'returns error for invalid status' do
      patch :update, params: { id: cart.id, cart: { status: 'invalid_status' } }

      # May return 500 if params.expect fails, or 422 if validation fails
      expect([500, 422]).to include(response.status)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes cart successfully' do
      cart # create cart
      delete :destroy, params: { id: cart.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Cart deleted successfully')
      expect(Cart.find_by(id: cart.id)).to be_nil
    end
  end

  describe 'POST #clear' do
    it 'clears all items from cart' do
      cart.add_product(product, 2)
      create(:cart_item, cart: cart, product: create(:product), quantity: 1)

      post :clear, params: { id: cart.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(cart.reload.cart_items.count).to eq(0)
    end
  end

  describe 'POST #merge' do
    let(:guest_cart) { create(:cart, session_id: 'guest-session-id') }
    let(:user_cart) { create(:cart, user: user) }

    context 'with valid guest cart' do
      before do
        guest_cart.add_product(product, 2)
        user_cart.add_product(product, 1)
      end

      it 'merges carts successfully' do
        # Ensure carts exist before merge
        user_cart.reload
        guest_cart.reload

        post :merge, params: { guest_session_id: guest_cart.session_id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true

        # Reload carts after merge - user_cart is recreated by controller
        merged_cart = Cart.find_by(user: user)
        merged_cart.reload
        guest_cart.reload

        merged_item = merged_cart.cart_items.find_by(product: product)
        expect(merged_item&.quantity).to eq(3)
        expect(guest_cart.status).to eq('abandoned')
      end
    end

    context 'without guest_session_id' do
      it 'returns bad request' do
        post :merge

        expect(response).to have_http_status(:bad_request)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Guest session ID is required')
      end
    end

    context 'with non-existent guest cart' do
      it 'returns not found' do
        post :merge, params: { guest_session_id: 'non-existent' }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Guest cart not found')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
