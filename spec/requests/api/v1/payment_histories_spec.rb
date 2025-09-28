# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PaymentHistories', type: :request do
  let(:user) { create(:user, role: 'admin') }
  let(:customer) { create(:user, role: 'customer') }
  let(:order) { create(:order, user: customer) }
  let(:payment_method) { create(:payment_method) }
  let(:payment) { create(:payment, order: order, payment_method: payment_method) }
  let(:payment_history) { create(:payment_history, payment: payment) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{JwtEncodeService.encode(user)}" } }
  let(:customer_headers) { { 'Authorization' => "Bearer #{JwtEncodeService.encode(customer)}" } }

  describe 'GET /api/v1/payment_histories' do
    context 'when user is admin' do
      it 'returns all payment histories' do
        payment_history
        get '/api/v1/payment_histories', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to be_an(Array)
      end

      it 'filters by payment_id' do
        payment_history
        get '/api/v1/payment_histories', params: { payment_id: payment.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].all? { |h| h['payment_id'] == payment.id }).to be true
      end

      it 'filters by action' do
        create(:payment_history, payment: payment, action: 'created')
        create(:payment_history, payment: payment, action: 'status_changed')

        get '/api/v1/payment_histories', params: { action: 'created' }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].all? { |h| h['action'] == 'created' }).to be true
      end

      it 'filters by date range' do
        create(:payment_history, payment: payment, performed_at: 1.day.ago)
        create(:payment_history, payment: payment, performed_at: 1.week.ago)

        get '/api/v1/payment_histories',
            params: {
              start_date: 2.days.ago.iso8601,
              end_date: Time.current.iso8601
            },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
      end
    end

    context 'when user is customer' do
      it 'returns only their payment histories' do
        other_customer = create(:user, role: 'customer')
        other_order = create(:order, user: other_customer)
        other_payment = create(:payment, order: other_order, payment_method: payment_method)
        create(:payment_history, payment: other_payment)

        payment_history
        get '/api/v1/payment_histories', headers: customer_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].all? { |h| h['payment']['order']['user_id'] == customer.id }).to be true
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/payment_histories'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/payment_histories/:id' do
    context 'when user is admin' do
      it 'returns payment history details' do
        get "/api/v1/payment_histories/#{payment_history.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']['id']).to eq(payment_history.id)
      end
    end

    context 'when user is customer' do
      it 'returns payment history if it belongs to their payment' do
        get "/api/v1/payment_histories/#{payment_history.id}", headers: customer_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(payment_history.id)
      end

      it 'returns forbidden for other users payment history' do
        other_customer = create(:user, role: 'customer')
        other_order = create(:order, user: other_customer)
        other_payment = create(:payment, order: other_order, payment_method: payment_method)
        other_history = create(:payment_history, payment: other_payment)

        get "/api/v1/payment_histories/#{other_history.id}", headers: customer_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/payment_histories/:id/timeline' do
    it 'returns payment timeline' do
      get "/api/v1/payment_histories/#{payment_history.id}/timeline", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_an(Array)
    end
  end

  describe 'GET /api/v1/payment_histories/:id/audit_trail' do
    it 'returns audit trail details' do
      get "/api/v1/payment_histories/#{payment_history.id}/audit_trail", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('id')
    end
  end

  describe 'GET /api/v1/payment_histories/statistics' do
    context 'when user is admin' do
      it 'returns payment history statistics' do
        create(:payment_history, payment: payment, action: 'created')
        create(:payment_history, payment: payment, action: 'status_changed')

        get '/api/v1/payment_histories/statistics', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('total_actions')
        expect(json_response['data']).to have_key('actions_by_type')
      end

      it 'filters statistics by date range' do
        create(:payment_history, payment: payment, performed_at: 1.day.ago)
        create(:payment_history, payment: payment, performed_at: 1.week.ago)

        get '/api/v1/payment_histories/statistics',
            params: {
              start_date: 2.days.ago.iso8601,
              end_date: Time.current.iso8601
            },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['total_actions']).to eq(1)
      end
    end

    context 'when user is customer' do
      it 'returns forbidden' do
        get '/api/v1/payment_histories/statistics', headers: customer_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/payment_histories/search' do
    it 'searches payment histories' do
      create(:payment_history, payment: payment, notes: 'Payment created successfully')

      get '/api/v1/payment_histories/search',
          params: { q: 'created' },
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('results')
    end
  end

  describe 'GET /api/v1/payment_histories/export' do
    context 'when user is admin' do
      it 'exports payment history data' do
        create(:payment_history, payment: payment)

        get '/api/v1/payment_histories/export', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('export_info')
        expect(json_response['data']).to have_key('data')
      end
    end

    context 'when user is customer' do
      it 'returns forbidden' do
        get '/api/v1/payment_histories/export', headers: customer_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/payment_histories/my_recent' do
    it 'returns recent payment histories for current user' do
      create(:payment_history, payment: payment)

      get '/api/v1/payment_histories/my_recent', headers: customer_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('recent_payments')
    end
  end

  describe 'GET /api/v1/payment_histories/status_changes' do
    it 'returns status change histories' do
      create(:payment_history, payment: payment, action: 'status_changed')

      get '/api/v1/payment_histories/status_changes', headers: customer_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('status_changes')
    end
  end

  describe 'GET /api/v1/payment_histories/refunds' do
    it 'returns refund histories' do
      create(:payment_history, payment: payment, action: 'refunded')

      get '/api/v1/payment_histories/refunds', headers: customer_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('refunds')
    end
  end

  describe 'GET /api/v1/payment_histories/failures' do
    it 'returns failure histories' do
      create(:payment_history, payment: payment, action: 'failed')

      get '/api/v1/payment_histories/failures', headers: customer_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('failures')
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
