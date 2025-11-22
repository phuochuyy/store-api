# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::PaymentMethodsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:payment_method) { create(:payment_method, :stripe, is_active: true) }

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
    before do
      payment_method
      create(:payment_method, :paypal, is_active: true)
      create(:payment_method, is_active: false)
    end

    it 'returns active payment methods' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['payment_methods']).to be_an(Array)
      # Should only return active payment methods
      expect(json_response['data']['payment_methods'].all? { |pm| pm['is_active'] == true }).to be true
    end

    it 'filters by gateway_type' do
      get :index, params: { gateway_type: 'stripe' }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['payment_methods'].all? { |pm| pm['gateway_type'] == 'stripe' }).to be true
    end
  end

  describe 'GET #show' do
    it 'returns payment method details' do
      get :show, params: { id: payment_method.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['payment_method']).to be_present
      expect(json_response['data']['payment_method']['id']).to eq(payment_method.id)
    end

    context 'with non-existent payment method' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Payment method not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_payment_method_params) do
      {
        payment_method: {
          name: 'New Payment Method',
          description: 'Test payment method',
          gateway_type: 'stripe',
          processing_fee_percentage: 2.5,
          processing_fee_fixed: 0.0,
          is_active: true,
          gateway_config: { api_key: 'test_key' }
        }
      }
    end

    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(Payments::PaymentMethodService).to receive(:create_payment_method).and_return({
                                                                                              success: true,
                                                                                              message: 'Payment method created successfully',
                                                                                              payment_method: payment_method
                                                                                            })
      end

      it 'creates payment method successfully' do
        post :create, params: valid_payment_method_params

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Payment method created successfully')
        expect(json_response['data']['payment_method']).to be_present
      end

      it 'returns error when service fails' do
        allow(Payments::PaymentMethodService).to receive(:create_payment_method)
          .and_return({
                        success: false,
                        message: 'Payment method creation failed',
                        errors: ['Name has already been taken']
                      })

        post :create, params: valid_payment_method_params

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Payment method creation failed')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :create, params: valid_payment_method_params

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
        allow(Payments::PaymentMethodService).to receive(:update_payment_method)
          .and_return({
                        success: true,
                        message: 'Payment method updated successfully',
                        payment_method: payment_method
                      })
      end

      it 'updates payment method successfully' do
        patch :update, params: {
          id: payment_method.id,
          payment_method: {
            name: 'Updated Payment Method',
            is_active: false
          }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Payment method updated successfully')
      end

      it 'returns error when service fails' do
        allow(Payments::PaymentMethodService).to receive(:update_payment_method)
          .and_return({
                        success: false,
                        message: 'Payment method update failed',
                        errors: ['Name has already been taken']
                      })

        patch :update, params: {
          id: payment_method.id,
          payment_method: { name: 'Updated Name' }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        patch :update, params: {
          id: payment_method.id,
          payment_method: { name: 'Updated Name' }
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
        allow(Payments::PaymentMethodService).to receive(:deactivate_payment_method)
          .and_return({
                        success: true,
                        message: 'Payment method deactivated successfully'
                      })
      end

      it 'deactivates payment method successfully' do
        delete :destroy, params: { id: payment_method.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Payment method deactivated successfully')
      end

      it 'returns error when service fails' do
        allow(Payments::PaymentMethodService).to receive(:deactivate_payment_method)
          .and_return({
                        success: false,
                        message: 'Payment method deactivation failed',
                        errors: ['Cannot deactivate payment method with active payments']
                      })

        delete :destroy, params: { id: payment_method.id }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        delete :destroy, params: { id: payment_method.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #stats' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(Payments::PaymentMethodService).to receive(:get_payment_method_stats)
          .and_return({
                        success: true,
                        stats: {
                          total_payments: 100,
                          total_amount: 10_000.00,
                          average_amount: 100.00
                        },
                        period: 'month',
                        start_date: 1.month.ago.to_date,
                        end_date: Time.zone.today
                      })
      end

      it 'returns payment method statistics' do
        get :stats, params: { id: payment_method.id, period: 'month' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['data']['stats']).to be_present
        expect(json_response['data']['period']).to eq('month')
      end

      it 'uses default period if not provided' do
        get :stats, params: { id: payment_method.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['data']['period']).to eq('month')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :stats, params: { id: payment_method.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #calculate_fees' do
    it 'calculates processing fees successfully' do
      allow(Payments::PaymentMethodService).to receive(:calculate_processing_fees).and_return({
                                                                                                success: true,
                                                                                                original_amount: 100.00,
                                                                                                processing_fee: 2.50,
                                                                                                total_amount: 102.50,
                                                                                                fee_breakdown: {
                                                                                                  percentage_fee: 2.50,
                                                                                                  fixed_fee: 0.00
                                                                                                }
                                                                                              })

      post :calculate_fees, params: {
        amount: 100.00,
        payment_method_id: payment_method.id
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['processing_fee']).to eq(2.50)
      expect(json_response['data']['total_amount']).to eq(102.50)
    end

    it 'returns error when amount is missing' do
      post :calculate_fees, params: {
        payment_method_id: payment_method.id
      }

      expect(response).to have_http_status(:bad_request)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Amount is required')
    end

    it 'returns error when payment_method_id is missing' do
      post :calculate_fees, params: {
        amount: 100.00
      }

      expect(response).to have_http_status(:bad_request)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Payment method ID is required')
    end

    it 'returns error when payment method not found' do
      post :calculate_fees, params: {
        amount: 100.00,
        payment_method_id: 999_999
      }

      expect(response).to have_http_status(:not_found)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Payment method not found')
    end
  end
end
# rubocop:enable Metrics/BlockLength
