require 'rails_helper'

RSpec.describe 'Api::V1::CartItems', type: :request do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 100.0) }
  let(:cart) { create(:cart, user: user) }
  let(:cart_item) { create(:cart_item, cart: cart, product: product) }
  let(:headers) { { 'Authorization' => "Bearer #{user.generate_jwt}" } }

  describe 'GET /api/v1/carts/:cart_id/cart_items' do
    let!(:cart_items) { create_list(:cart_item, 3, cart: cart) }

    it 'returns cart items' do
      get "/api/v1/carts/#{cart.id}/cart_items", headers: headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['data']).to include('cart_items', 'total_items', 'total_amount')
    end
  end

  describe 'GET /api/v1/carts/:cart_id/cart_items/:id' do
    it 'returns specific cart item' do
      get "/api/v1/carts/#{cart.id}/cart_items/#{cart_item.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['data']).to include('cart_item', 'product')
    end
  end

  describe 'POST /api/v1/carts/:cart_id/cart_items' do
    it 'adds product to cart' do
      expect do
        post "/api/v1/carts/#{cart.id}/cart_items",
             params: { cart_item: { product_id: product.id, quantity: 2 } },
             headers: headers
      end.to change(CartItem, :count).by(1)

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Product added to cart successfully')
    end

    it 'increments quantity for existing product' do
      create(:cart_item, cart: cart, product: product, quantity: 1)

      expect do
        post "/api/v1/carts/#{cart.id}/cart_items",
             params: { cart_item: { product_id: product.id, quantity: 2 } },
             headers: headers
      end.not_to change(CartItem, :count)

      cart_item = cart.cart_items.find_by(product: product)
      expect(cart_item.quantity).to eq(3)
    end

    it 'returns error for out of stock product' do
      out_of_stock_product = create(:product, stock_quantity: 0)

      post "/api/v1/carts/#{cart.id}/cart_items",
           params: { cart_item: { product_id: out_of_stock_product.id, quantity: 1 } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = response.parsed_body

      expect(json_response['success']).to be false
      expect(json_response['error']).to eq('Product is out of stock')
    end
  end

  describe 'PUT /api/v1/carts/:cart_id/cart_items/:id' do
    it 'updates cart item quantity' do
      put "/api/v1/carts/#{cart.id}/cart_items/#{cart_item.id}",
          params: { cart_item: { quantity: 5 } },
          headers: headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(cart_item.reload.quantity).to eq(5)
    end

    it 'removes item when quantity is 0' do
      expect do
        put "/api/v1/carts/#{cart.id}/cart_items/#{cart_item.id}",
            params: { cart_item: { quantity: 0 } },
            headers: headers
      end.to change(CartItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/carts/:cart_id/cart_items/:id' do
    it 'removes cart item' do
      expect do
        delete "/api/v1/carts/#{cart.id}/cart_items/#{cart_item.id}", headers: headers
      end.to change(CartItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Product removed from cart successfully')
    end
  end
end
