# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::ProductReviewsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:product) { create(:product) }
  let(:review) { create(:product_review, product: product, user: user, status: 'approved') }

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
      review
      create(:product_review, product: product, status: 'approved')
      create(:product_review, product: product, status: 'pending') # Should not appear
    end

    it 'returns approved reviews for a product' do
      get :index, params: { product_id: product.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['reviews']).to be_an(Array)
      expect(json_response['data']['reviews'].length).to eq(2) # Only approved
      expect(json_response['data']['pagination']).to be_present
    end

    it 'returns all approved reviews when product_id is not provided' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['reviews']).to be_an(Array)
    end

    it 'supports pagination' do
      get :index, params: { product_id: product.id, page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['pagination']['per_page']).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns review details' do
      get :show, params: { id: review.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['review']).to be_present
      expect(json_response['data']['review']['id']).to eq(review.id)
    end

    context 'with non-existent review' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Review not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_review_params) do
      {
        product_id: product.id,
        review: {
          rating: 5,
          title: 'Great product',
          content: 'This is an excellent product',
          verified_purchase: true
        }
      }
    end

    it 'creates review successfully' do
      post :create, params: valid_review_params

      expect(response).to have_http_status(:created)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('Pending admin approval')
      expect(json_response['data']['review']).to be_present
      expect(json_response['data']['review']['status']).to eq('pending')
    end

    it 'returns error when product not found' do
      post :create, params: {
        product_id: 999_999,
        review: { rating: 5, title: 'Test', content: 'Test' }
      }

      expect(response).to have_http_status(:not_found)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Product not found')
    end

    it 'returns error when user already reviewed product' do
      create(:product_review, product: product, user: user)

      post :create, params: valid_review_params

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You have already reviewed this product')
    end
  end

  describe 'PATCH #update' do
    let(:user_review) { create(:product_review, product: product, user: user, status: 'approved') }

    it 'updates own review successfully' do
      patch :update, params: {
        id: user_review.id,
        review: {
          rating: 4,
          title: 'Updated review',
          content: 'Updated content'
        }
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(user_review.reload.status).to eq('pending') # Re-approval required
    end

    it 'returns error when updating another user review' do
      other_user = create(:user)
      other_review = create(:product_review, product: product, user: other_user)

      patch :update, params: {
        id: other_review.id,
        review: { rating: 1 }
      }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only update your own reviews')
    end
  end

  describe 'DELETE #destroy' do
    let(:user_review) { create(:product_review, product: product, user: user) }

    it 'deletes own review successfully' do
      delete :destroy, params: { id: user_review.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(ProductReview.find_by(id: user_review.id)).to be_nil
    end

    it 'allows admin to delete any review' do
      request.headers['Authorization'] = "Bearer #{admin_token}"

      delete :destroy, params: { id: review.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end

    it 'returns error when deleting another user review' do
      other_user = create(:user)
      other_review = create(:product_review, product: product, user: other_user)

      delete :destroy, params: { id: other_review.id }

      expect(response).to have_http_status(:forbidden)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('You can only delete your own reviews')
    end
  end

  describe 'POST #helpful' do
    it 'marks review as helpful' do
      post :helpful, params: { id: review.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['review']['helpful_count']).to be >= 1
    end
  end
end
# rubocop:enable Metrics/BlockLength
