# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::PromotionsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:promotion) { create(:promotion, is_active: true) }
  let(:order) { create(:order, user: user) }

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
      promotion
      create(:promotion, is_active: false)
    end

    it 'returns all promotions' do
      allow(Discounts::PromotionService).to receive(:list_promotions).and_return({
                                                                                   promotions: [promotion],
                                                                                   pagination: { current_page: 1,
                                                                                                 total_pages: 1, total_count: 1, per_page: 20 }
                                                                                 })

      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end
  end

  describe 'GET #show' do
    it 'returns promotion details' do
      allow(Discounts::PromotionService).to receive(:find_promotion).and_return({
                                                                                  id: promotion.id,
                                                                                  name: promotion.name,
                                                                                  promotion_type: promotion.promotion_type
                                                                                })

      get :show, params: { id: promotion.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    context 'with non-existent promotion' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Promotion not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_promotion_params) do
      {
        promotion: {
          name: 'New Promotion',
          description: 'Test promotion',
          promotion_type: 'discount',
          is_active: true
        }
      }
    end

    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(PromotionValidator).to receive(:new).and_return(double(valid?: true, errors: double(full_messages: [])))
        allow(Discounts::PromotionService).to receive(:create_promotion).and_return({
                                                                                      success: true,
                                                                                      promotion: promotion
                                                                                    })
      end

      it 'creates promotion successfully' do
        post :create, params: valid_promotion_params

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Promotion created successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :create, params: valid_promotion_params

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
        allow(PromotionValidator).to receive(:new).and_return(double(valid?: true, errors: double(full_messages: [])))
        allow(Discounts::PromotionService).to receive(:update_promotion).and_return({
                                                                                      success: true,
                                                                                      promotion: promotion
                                                                                    })
      end

      it 'updates promotion successfully' do
        patch :update, params: {
          id: promotion.id,
          promotion: {
            name: 'Updated Promotion'
          }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Promotion updated successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        patch :update, params: {
          id: promotion.id,
          promotion: { name: 'Updated Name' }
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
        allow(Discounts::PromotionService).to receive(:delete_promotion).and_return({
                                                                                      success: true
                                                                                    })
      end

      it 'deletes promotion successfully' do
        delete :destroy, params: { id: promotion.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Promotion deleted successfully')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        delete :destroy, params: { id: promotion.id }

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
        allow(Discounts::PromotionService).to receive(:get_promotion_stats).and_return({
                                                                                         total_usage: 50,
                                                                                         total_discount: 500.00
                                                                                       })
      end

      it 'returns promotion statistics' do
        get :stats, params: { id: promotion.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        get :stats, params: { id: promotion.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'GET #applicable' do
    it 'returns applicable promotions for an order' do
      allow(Discounts::PromotionService).to receive(:get_applicable_promotions).and_return({
                                                                                             promotions: [promotion]
                                                                                           })

      get :applicable, params: { order_id: order.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'returns error when order_id is missing' do
      get :applicable

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Order ID is required')
    end

    it 'returns error when order not found' do
      get :applicable, params: { order_id: 999_999 }

      expect(response).to have_http_status(:not_found)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Order not found')
    end
  end

  describe 'POST #apply' do
    it 'applies promotion to order successfully' do
      allow(Discounts::PromotionService).to receive(:apply_promotion_to_order)
        .and_return({
                      success: true,
                      message: 'Promotion applied successfully'
                    })

      post :apply, params: {
        id: promotion.id,
        order_id: order.id
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Promotion applied successfully')
    end

    it 'returns error when order_id is missing' do
      post :apply, params: { id: promotion.id }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Order ID is required')
    end
  end
end
# rubocop:enable Metrics/BlockLength
