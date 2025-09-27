require 'rails_helper'

RSpec.describe 'Api::V1::Statistics', type: :request do
  let!(:admin_user) { create(:user, role: 'admin') }
  let!(:customer_user) { create(:user, role: 'customer') }
  let!(:brand) { create(:brand) }
  let!(:category) { create(:category) }
  let!(:phone) { create(:phone, brand: brand, category: category, price: 1000, stock_quantity: 5) }
  let!(:phone2) { create(:phone, brand: brand, category: category, price: 500, stock_quantity: 15) }

  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  before do
    # Create some test data
    create_list(:user, 3, role: 'customer')
    create_list(:order, 5, total_amount: 1000, status: 'confirmed')
    create_list(:order, 2, total_amount: 500, status: 'pending')
    create_list(:order_item, 3, phone: phone, quantity: 2)
    create_list(:order_item, 2, phone: phone2, quantity: 1)
  end

  describe 'GET /api/v1/statistics/dashboard' do
    context 'as admin' do
      it 'returns dashboard statistics' do
        get '/api/v1/statistics/dashboard', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to include(
          'total_orders',
          'total_revenue',
          'total_phones',
          'total_customers',
          'orders_by_status',
          'top_selling_phones',
          'revenue_by_month'
        )

        expect(json_response['total_orders']).to eq(7)
        expect(json_response['total_phones']).to eq(2)
        expect(json_response['total_customers']).to eq(4) # 3 created + 1 customer_user
        expect(json_response['orders_by_status']).to be_a(Hash)
        expect(json_response['top_selling_phones']).to be_an(Array)
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        get '/api/v1/statistics/dashboard', headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Admin access required')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/statistics/dashboard'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/statistics/inventory' do
    context 'as admin' do
      it 'returns inventory statistics' do
        get '/api/v1/statistics/inventory', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to include(
          'low_stock_phones',
          'total_inventory_value',
          'phones_by_brand',
          'phones_by_category'
        )

        expect(json_response['low_stock_phones']).to be_an(Array)
        expect(json_response['total_inventory_value']).to be_present
        expect(json_response['phones_by_brand']).to be_a(Hash)
        expect(json_response['phones_by_category']).to be_a(Hash)
      end

      it 'includes low stock phones' do
        get '/api/v1/statistics/inventory', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        # phone has stock_quantity: 5, which is < 10
        low_stock_phones = json_response['low_stock_phones']
        expect(low_stock_phones).to be_an(Array)
        expect(low_stock_phones.length).to be >= 1
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        get '/api/v1/statistics/inventory', headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/statistics/sales' do
    context 'as admin' do
      it 'returns sales statistics without date range' do
        get '/api/v1/statistics/sales', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to include(
          'daily_sales',
          'top_customers'
        )

        expect(json_response['daily_sales']).to be_a(Hash)
        expect(json_response['top_customers']).to be_an(Array)
      end

      it 'returns sales statistics with date range' do
        start_date = 1.month.ago.strftime('%Y-%m-%d')
        end_date = Date.current.strftime('%Y-%m-%d')

        get '/api/v1/statistics/sales',
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response).to include(
          'daily_sales',
          'top_customers'
        )
      end

      it 'handles invalid date range' do
        get '/api/v1/statistics/sales',
            params: { start_date: 'invalid-date', end_date: 'invalid-date' },
            headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        # Should still return data but with default date range
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        get '/api/v1/statistics/sales', headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'authentication and authorization' do
    it 'requires authentication for all statistics endpoints' do
      get '/api/v1/statistics/dashboard'
      expect(response).to have_http_status(:unauthorized)

      get '/api/v1/statistics/inventory'
      expect(response).to have_http_status(:unauthorized)

      get '/api/v1/statistics/sales'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires admin role for all statistics endpoints' do
      get '/api/v1/statistics/dashboard', headers: { 'Authorization' => "Bearer #{customer_token}" }
      expect(response).to have_http_status(:forbidden)

      get '/api/v1/statistics/inventory', headers: { 'Authorization' => "Bearer #{customer_token}" }
      expect(response).to have_http_status(:forbidden)

      get '/api/v1/statistics/sales', headers: { 'Authorization' => "Bearer #{customer_token}" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
