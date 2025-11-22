# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::DiscountsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:discount) { create(:discount, is_active: true) }

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
      discount
      create(:discount, is_active: false)
    end

    it 'returns all discounts' do
      allow(Discounts::DiscountService).to receive(:list_discounts).and_return({
                                                                                 discounts: [discount],
                                                                                 pagination: {
                                                                                   current_page: 1,
                                                                                   total_pages: 1,
                                                                                   total_count: 1,
                                                                                   per_page: 20
                                                                                 }
                                                                               })

      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'filters by discount_type' do
      allow(Discounts::DiscountService).to receive(:list_discounts).and_return({
                                                                                 discounts: [],
                                                                                 pagination: {
                                                                                   current_page: 1,
                                                                                   total_pages: 0,
                                                                                   total_count: 0,
                                                                                   per_page: 20
                                                                                 }
                                                                               })

      get :index, params: { discount_type: 'percentage' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    it 'returns discount details' do
      allow(Discounts::DiscountService).to receive(:find_discount).and_return({
                                                                                id: discount.id,
                                                                                name: discount.name,
                                                                                discount_type: discount.discount_type,
                                                                                value: discount.value
                                                                              })

      get :show, params: { id: discount.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    context 'with non-existent discount' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Discount not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_discount_params) do
      {
        discount: {
          name: 'New Discount',
          description: 'Test discount',
          discount_type: 'percentage',
          value: 10.0,
          is_active: true
        }
      }
    end

    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(DiscountValidator).to receive(:new).and_return(double(valid?: true, errors: double(full_messages: [])))
        allow(Discounts::DiscountService).to receive(:create_discount).and_return({
                                                                                    success: true,
                                                                                    discount: discount
                                                                                  })
      end

      it 'creates discount successfully' do
        post :create, params: valid_discount_params

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Discount created successfully')
      end

      it 'returns error when validation fails' do
        validator = double(valid?: false, errors: double(full_messages: ['Name is required']))
        allow(DiscountValidator).to receive(:new).and_return(validator)

        post :create, params: valid_discount_params

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :create, params: valid_discount_params

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
        allow(DiscountValidator).to receive(:new).and_return(double(valid?: true, errors: double(full_messages: [])))
        allow(Discounts::DiscountService).to receive(:update_discount).and_return({
                                                                                    success: true,
                                                                                    discount: discount
                                                                                  })
      end

      it 'updates discount successfully' do
        patch :update, params: {
          id: discount.id,
          discount: {
            name: 'Updated Discount'
          }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Discount updated successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        patch :update, params: {
          id: discount.id,
          discount: { name: 'Updated Name' }
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
        allow(Discounts::DiscountService).to receive(:delete_discount).and_return({
                                                                                    success: true
                                                                                  })
      end

      it 'deletes discount successfully' do
        delete :destroy, params: { id: discount.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Discount deleted successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        delete :destroy, params: { id: discount.id }

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
        allow(Discounts::DiscountService).to receive(:get_discount_stats).and_return({
                                                                                       total_usage: 100,
                                                                                       total_savings: 1000.00
                                                                                     })
      end

      it 'returns discount statistics' do
        get :stats, params: { id: discount.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :stats, params: { id: discount.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #generate_codes' do
    it 'generates discount codes' do
      allow(Discounts::DiscountService).to receive(:generate_discount_codes).and_return({
                                                                                          success: true,
                                                                                          codes: %w[CODE1 CODE2 CODE3]
                                                                                        })

      post :generate_codes, params: {
        id: discount.id,
        quantity: 3
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['codes']).to be_an(Array)
    end

    it 'returns error for invalid quantity' do
      post :generate_codes, params: {
        id: discount.id,
        quantity: 0
      }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end

  describe 'POST #validate' do
    it 'validates discount code successfully' do
      allow(Discounts::DiscountService).to receive(:validate_discount_code).and_return({
                                                                                         valid: true,
                                                                                         discount: discount,
                                                                                         discount_amount: 10.00
                                                                                       })

      post :validate, params: {
        code: 'TESTCODE',
        order_amount: 100.00
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'returns error for invalid code' do
      allow(Discounts::DiscountService).to receive(:validate_discount_code).and_return({
                                                                                         valid: false,
                                                                                         error: 'Invalid discount code'
                                                                                       })

      post :validate, params: {
        code: 'INVALID',
        order_amount: 100.00
      }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end

    it 'returns error when code is missing' do
      post :validate, params: {
        order_amount: 100.00
      }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Discount code is required')
    end
  end
end
# rubocop:enable Metrics/BlockLength
