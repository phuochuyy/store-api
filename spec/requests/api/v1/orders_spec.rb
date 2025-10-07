require 'rails_helper'

RSpec.describe 'Api::V1::Orders', type: :request do
  let!(:admin_user) { create(:user, role: 'admin') }
  let!(:customer_user) { create(:user, role: 'customer') }
  let!(:brand) { create(:brand) }
  let!(:category) { create(:category) }
  let!(:product) { create(:product, brand: brand, category: category, stock_quantity: 10) }
  let!(:product2) { create(:product, brand: brand, category: category, stock_quantity: 5) }

  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  let(:valid_order_params) do
    {
      order: {
        customer_name: 'John Doe',
        customer_email: 'john@example.com',
        customer_phone: '1234567890',
        status: 'pending'
      },
      order_items: [
        {
          product_id: product.id,
          quantity: 2
        },
        {
          product_id: product2.id,
          quantity: 1
        }
      ]
    }
  end

  describe 'GET /api/v1/orders' do
    let!(:order) { create(:order, customer_email: 'test@example.com') }

    context 'as admin' do
      it 'returns all orders' do
        get '/api/v1/orders', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['orders']).to be_an(Array)
        expect(json_response['data']['pagination']).to be_present
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        get '/api/v1/orders', headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/orders'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/orders/:id' do
    let!(:order) { create(:order, customer_email: 'test@example.com') }
    let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2) }

    context 'with valid order id' do
      it 'returns order details' do
        get "/api/v1/orders/#{order.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['order']).to be_present
        expect(json_response['order']['id']).to eq(order.id)
        expect(json_response['order_items']).to be_an(Array)
        expect(json_response['order_items'].first['quantity']).to eq(2)
      end
    end

    context 'with invalid order id' do
      it 'returns not found' do
        get '/api/v1/orders/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/orders' do
    context 'with valid parameters' do
      it 'creates a new order with order items' do
        expect do
          post '/api/v1/orders', params: valid_order_params, headers: { 'Authorization' => "Bearer #{customer_token}" }
        end.to change(Order, :count).by(1)
                                    .and change(OrderItem, :count).by(2)

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['order']).to be_present
        expect(json_response['order']['customer_name']).to eq('John Doe')
        expect(json_response['order']['total_amount']).to be_present
      end

      it 'reduces product stock quantities' do
        initial_stock = product.stock_quantity
        initial_stock2 = product2.stock_quantity

        post '/api/v1/orders', params: valid_order_params, headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:created)
        product.reload
        product2.reload

        expect(product.stock_quantity).to eq(initial_stock - 2)
        expect(product2.stock_quantity).to eq(initial_stock2 - 1)
      end
    end

    context 'with insufficient stock' do
      let(:invalid_order_params) do
        {
          order: {
            customer_name: 'John Doe',
            customer_email: 'john@example.com',
            customer_phone: '1234567890',
            status: 'pending'
          },
          order_items: [
            {
              product_id: product.id,
              quantity: 100 # More than available stock
            }
          ]
        }
      end

      it 'returns error for insufficient stock' do
        post '/api/v1/orders', params: invalid_order_params, headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid order parameters' do
      let(:invalid_params) do
        {
          order: {
            customer_name: '',
            customer_email: 'invalid-email',
            customer_phone: '',
            status: 'pending'
          },
          order_items: []
        }
      end

      it 'returns validation errors' do
        post '/api/v1/orders', params: invalid_params, headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'PUT /api/v1/orders/:id' do
    let!(:order) { create(:order, customer_email: 'test@example.com', status: 'pending') }
    let(:update_params) do
      {
        order: {
          status: 'confirmed'
        }
      }
    end

    context 'as admin' do
      it 'updates the order' do
        put "/api/v1/orders/#{order.id}", params: update_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['order']).to be_present
        expect(json_response['order']['status']).to eq('confirmed')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        put "/api/v1/orders/#{order.id}", params: update_params,
                                          headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'DELETE /api/v1/orders/:id' do
    let!(:order) { create(:order, customer_email: 'test@example.com') }

    context 'as admin' do
      it 'deletes the order' do
        expect do
          delete "/api/v1/orders/#{order.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Order, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['message']).to eq('Order deleted successfully')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        delete "/api/v1/orders/#{order.id}", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST /api/v1/orders/:id/confirm' do
    let!(:order) { create(:order, status: 'pending') }
    let!(:order_item) { create(:order_item, order: order) }

    context 'as admin' do
      it 'confirms the order successfully' do
        post "/api/v1/orders/#{order.id}/confirm", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Order confirmed successfully')
        expect(json_response['data']['order']['status']).to eq('confirmed')
        expect(order.reload.status).to eq('confirmed')
        expect(order.confirmed_at).to be_present
      end

      it 'returns error when order cannot be confirmed' do
        order.update!(status: 'confirmed')
        post "/api/v1/orders/#{order.id}/confirm", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Order cannot be confirmed')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post "/api/v1/orders/#{order.id}/confirm", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/orders/#{order.id}/confirm"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/orders/:id/cancel' do
    let!(:order) { create(:order, status: 'pending') }
    let!(:order_item) { create(:order_item, order: order) }

    context 'as admin' do
      it 'cancels the order successfully' do
        post "/api/v1/orders/#{order.id}/cancel",
             params: { reason: 'Customer requested' },
             headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Order cancelled successfully')
        expect(json_response['data']['order']['status']).to eq('cancelled')
        expect(order.reload.status).to eq('cancelled')
        expect(order.cancelled_at).to be_present
        expect(order.cancellation_reason).to eq('Customer requested')
      end

      it 'cancels the order without reason' do
        post "/api/v1/orders/#{order.id}/cancel", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(order.reload.status).to eq('cancelled')
        expect(order.cancellation_reason).to be_nil
      end

      it 'returns error when order cannot be cancelled' do
        order.update!(status: 'delivered')
        post "/api/v1/orders/#{order.id}/cancel", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Order cannot be cancelled')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post "/api/v1/orders/#{order.id}/cancel", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/orders/#{order.id}/cancel"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/orders/:id/ship' do
    let!(:order) { create(:order, status: 'confirmed') }
    let!(:order_item) { create(:order_item, order: order) }

    context 'as admin' do
      it 'ships the order successfully with tracking info' do
        post "/api/v1/orders/#{order.id}/ship",
             params: {
               tracking_number: 'TRK123456',
               carrier: 'DHL'
             },
             headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Order shipped successfully')
        expect(json_response['data']['order']['status']).to eq('shipped')
        expect(json_response['data']['order']['tracking_number']).to eq('TRK123456')
        expect(json_response['data']['order']['carrier']).to eq('DHL')
        expect(order.reload.status).to eq('shipped')
        expect(order.tracking_number).to eq('TRK123456')
        expect(order.carrier).to eq('DHL')
        expect(order.shipped_at).to be_present
      end

      it 'ships the order without tracking info' do
        post "/api/v1/orders/#{order.id}/ship", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(order.reload.status).to eq('shipped')
        expect(order.tracking_number).to be_nil
        expect(order.carrier).to be_nil
        expect(order.shipped_at).to be_present
      end

      it 'returns error when order cannot be shipped' do
        order.update!(status: 'pending')
        post "/api/v1/orders/#{order.id}/ship", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Order cannot be shipped')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post "/api/v1/orders/#{order.id}/ship", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/orders/#{order.id}/ship"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/orders/:id/deliver' do
    let!(:order) { create(:order, status: 'shipped') }
    let!(:order_item) { create(:order_item, order: order) }

    context 'as admin' do
      it 'delivers the order successfully with delivery info' do
        post "/api/v1/orders/#{order.id}/deliver",
             params: {
               delivery_notes: 'Delivered to front door',
               delivery_signature: 'John Doe'
             },
             headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Order delivered successfully')
        expect(json_response['data']['order']['status']).to eq('delivered')
        expect(json_response['data']['order']['delivery_notes']).to eq('Delivered to front door')
        expect(json_response['data']['order']['delivery_signature']).to eq('John Doe')
        expect(order.reload.status).to eq('delivered')
        expect(order.delivery_notes).to eq('Delivered to front door')
        expect(order.delivery_signature).to eq('John Doe')
        expect(order.delivered_at).to be_present
      end

      it 'delivers the order without delivery info' do
        post "/api/v1/orders/#{order.id}/deliver", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(order.reload.status).to eq('delivered')
        expect(order.delivery_notes).to be_nil
        expect(order.delivery_signature).to be_nil
        expect(order.delivered_at).to be_present
      end

      it 'returns error when order cannot be delivered' do
        order.update!(status: 'confirmed')
        post "/api/v1/orders/#{order.id}/deliver", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Order cannot be delivered')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post "/api/v1/orders/#{order.id}/deliver", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/orders/#{order.id}/deliver"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
