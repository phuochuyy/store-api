# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::StatisticsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

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
  let(:admin_token) { generate_token(admin_user) }

  before do
    request.headers['Content-Type'] = 'application/json'
    request.headers['Authorization'] = "Bearer #{user_token}"
  end

  describe 'GET #dashboard' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        create_list(:order, 5, total_amount: 100.00)
        create_list(:product, 10)
        create_list(:user, 3, role: 'customer')
      end

      it 'returns dashboard statistics' do
        get :dashboard

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['total_orders']).to eq(5)
        expect(json_response['data']['total_products']).to eq(10)
        expect(json_response['data']['total_customers']).to eq(3)
        expect(json_response['data']['total_revenue']).to be_present
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :dashboard

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #inventory' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        create(:product, stock_quantity: 5) # Low stock
        create(:product, stock_quantity: 0) # Out of stock
        create(:product, stock_quantity: 100, price: 50.00)
      end

      it 'returns inventory statistics' do
        get :inventory

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['low_stock_products']).to be_an(Array)
        expect(json_response['data']['out_of_stock_products']).to be_an(Array)
        expect(json_response['data']['total_inventory_value']).to be_present
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :inventory

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #sales' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        create_list(:order, 3, total_amount: 100.00, created_at: 10.days.ago)
        create_list(:order, 2, total_amount: 200.00, created_at: 5.days.ago)
      end

      it 'returns sales statistics' do
        get :sales

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['total_sales']).to be_present
        expect(json_response['total_orders']).to eq(5)
        expect(json_response['average_order_value']).to be_present
      end

      it 'filters by date range' do
        start_date = 15.days.ago.to_date.to_s
        end_date = 7.days.ago.to_date.to_s

        get :sales, params: { start_date: start_date, end_date: end_date }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['total_orders']).to eq(3) # Only orders in range
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :sales

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
