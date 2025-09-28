require 'rails_helper'

RSpec.describe 'Api::V1::OrderItems', type: :request do
  let!(:admin_user) { create(:user, role: 'admin') }
  let!(:customer_user) { create(:user, role: 'customer') }
  let!(:brand) { create(:brand) }
  let!(:category) { create(:category) }
  let!(:phone) { create(:phone, brand: brand, category: category, price: 1000, stock_quantity: 10) }
  let!(:order) { create(:order, customer_email: 'test@example.com') }

  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  let(:valid_order_item_params) do
    {
      order_item: {
        phone_id: phone.id,
        quantity: 2
      }
    }
  end

  describe 'GET /api/v1/orders/:order_id/order_items' do
    let!(:order_item1) { create(:order_item, order: order, phone: phone, quantity: 2) }
    let!(:order_item2) { create(:order_item, order: order, phone: phone, quantity: 1) }

    context 'as admin' do
      it 'returns order items for the order' do
        get "/api/v1/orders/#{order.id}/order_items", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(2)
        expect(json_response.first).to include('id', 'quantity', 'unit_price', 'phone')
      end
    end

    context 'as customer' do
      it 'returns order items for the order' do
        get "/api/v1/orders/#{order.id}/order_items", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(2)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/orders/#{order.id}/order_items"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid order id' do
      it 'returns not found' do
        get '/api/v1/orders/99999/order_items', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/order_items/:id' do
    let!(:order_item) { create(:order_item, order: order, phone: phone, quantity: 2) }

    context 'with valid order item id' do
      it 'returns order item details' do
        get "/api/v1/order_items/#{order_item.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['id']).to eq(order_item.id)
        expect(json_response['quantity']).to eq(2)
        expect(json_response['phone']).to be_present
      end
    end

    context 'with invalid order item id' do
      it 'returns not found' do
        get '/api/v1/order_items/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/orders/:order_id/order_items' do
    context 'with valid parameters' do
      it 'creates a new order item' do
        expect do
          post "/api/v1/orders/#{order.id}/order_items", params: valid_order_item_params,
                                                         headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(OrderItem, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['quantity']).to eq(2)
        expect(json_response['unit_price'].to_f).to eq(phone.price)
        expect(json_response['phone']).to be_present
      end

      it 'updates order total amount' do
        expect do
          post "/api/v1/orders/#{order.id}/order_items", params: valid_order_item_params,
                                                         headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to(change { order.reload.total_amount })
      end

      it 'sets unit price from phone price' do
        post "/api/v1/orders/#{order.id}/order_items", params: valid_order_item_params,
                                                       headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['unit_price'].to_f).to eq(phone.price)
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors for missing phone_id' do
        invalid_params = { order_item: { quantity: 2 } }
        post "/api/v1/orders/#{order.id}/order_items", params: invalid_params,
                                                       headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to be_present
      end

      it 'returns validation errors for missing quantity' do
        invalid_params = { order_item: { phone_id: phone.id } }
        post "/api/v1/orders/#{order.id}/order_items", params: invalid_params,
                                                       headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to be_present
      end

      it 'returns validation errors for zero quantity' do
        invalid_params = { order_item: { phone_id: phone.id, quantity: 0 } }
        post "/api/v1/orders/#{order.id}/order_items", params: invalid_params,
                                                       headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to be_present
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/orders/#{order.id}/order_items", params: valid_order_item_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/order_items/:id' do
    let!(:order_item) { create(:order_item, order: order, phone: phone, quantity: 2) }
    let(:update_params) { { order_item: { quantity: 3 } } }

    context 'with valid parameters' do
      it 'updates the order item' do
        put "/api/v1/order_items/#{order_item.id}", params: update_params,
                                                    headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['quantity']).to eq(3)
        expect(order_item.reload.quantity).to eq(3)
      end

      it 'updates order total amount' do
        expect do
          put "/api/v1/order_items/#{order_item.id}", params: update_params,
                                                      headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to(change { order.reload.total_amount })
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors' do
        invalid_params = { order_item: { quantity: 0 } }
        put "/api/v1/order_items/#{order_item.id}", params: invalid_params,
                                                    headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to be_present
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        put "/api/v1/order_items/#{order_item.id}", params: update_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/order_items/:id' do
    let!(:order_item) { create(:order_item, order: order, phone: phone, quantity: 2) }

    context 'with valid order item id' do
      it 'deletes the order item' do
        expect do
          delete "/api/v1/order_items/#{order_item.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(OrderItem, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'updates order total amount' do
        expect do
          delete "/api/v1/order_items/#{order_item.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to(change { order.reload.total_amount })
      end
    end

    context 'with invalid order item id' do
      it 'returns not found' do
        delete '/api/v1/order_items/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        delete "/api/v1/order_items/#{order_item.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
