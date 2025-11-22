# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::StockAlertsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:product) { create(:product, stock_quantity: 5) }
  let(:stock_alert) { create(:stock_alert, product: product) }

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

  describe 'GET #index' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:get_alerts).and_return({
                                                                                   success: true,
                                                                                   alerts: [stock_alert],
                                                                                   pagination: {
                                                                                     current_page: 1,
                                                                                     total_pages: 1,
                                                                                     total_count: 1,
                                                                                     per_page: 20
                                                                                   }
                                                                                 })
      end

      it 'returns stock alerts' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end

      it 'filters by status' do
        get :index, params: { status: 'active' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :index

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #show' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'returns stock alert details' do
        get :show, params: { id: stock_alert.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['alert']).to be_present
        expect(json_response['data']['product']).to be_present
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :show, params: { id: stock_alert.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'PATCH #update' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:update_alert)
          .and_return({
                        success: true,
                        message: 'Alert updated successfully',
                        alert: stock_alert
                      })
      end

      it 'updates stock alert successfully' do
        patch :update, params: {
          id: stock_alert.id,
          stock_alert: {
            threshold: 10
          }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        patch :update, params: {
          id: stock_alert.id,
          stock_alert: { threshold: 10 }
        }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'deletes stock alert successfully' do
        delete :destroy, params: { id: stock_alert.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Stock alert deleted successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        delete :destroy, params: { id: stock_alert.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #resolve' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:resolve_alert)
          .and_return({
                        success: true,
                        message: 'Alert resolved successfully',
                        alert: stock_alert
                      })
      end

      it 'resolves stock alert successfully' do
        post :resolve, params: {
          id: stock_alert.id,
          resolution_notes: 'Stock replenished'
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :resolve, params: { id: stock_alert.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #dismiss' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:dismiss_alert)
          .and_return({
                        success: true,
                        message: 'Alert dismissed successfully',
                        alert: stock_alert
                      })
      end

      it 'dismisses stock alert successfully' do
        post :dismiss, params: {
          id: stock_alert.id,
          dismissal_reason: 'False alarm'
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :dismiss, params: { id: stock_alert.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #bulk_operation' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:bulk_operation).and_return({
                                                                                       success: true,
                                                                                       message:
                                                                                         'Bulk operation completed',
                                                                                       processed_count: 2
                                                                                     })
      end

      it 'performs bulk operation successfully' do
        post :bulk_operation, params: {
          alert_ids: [stock_alert.id],
          action: 'resolve'
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :bulk_operation, params: {
          alert_ids: [stock_alert.id],
          action: 'resolve'
        }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #statistics' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockAlertService).to receive(:get_statistics).and_return({
                                                                                       success: true,
                                                                                       total_alerts: 10,
                                                                                       active_alerts: 5,
                                                                                       resolved_alerts: 3
                                                                                     })
      end

      it 'returns stock alert statistics' do
        get :statistics

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :statistics

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
