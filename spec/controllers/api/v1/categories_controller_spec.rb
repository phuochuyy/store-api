# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::CategoriesController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category) }

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
      category
      create(:category, name: 'Electronics')
      create(:category, name: 'Clothing')
    end

    it 'returns all categories' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['categories']).to be_an(Array)
      expect(json_response['data']['categories'].length).to be >= 3
      expect(json_response['data']['pagination']).to be_present
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['pagination']['current_page']).to eq(1)
      expect(json_response['data']['pagination']['per_page']).to eq(2)
    end

    it 'includes products count in response' do
      create(:product, category: category)
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      category_data = json_response['data']['categories'].find { |c| c['id'] == category.id }
      expect(category_data['products_count']).to eq(1)
    end
  end

  describe 'GET #show' do
    before do
      create(:product, category: category)
      create(:product, category: category)
    end

    it 'returns category details' do
      get :show, params: { id: category.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['category']).to be_present
      expect(json_response['data']['category']['id']).to eq(category.id)
      expect(json_response['data']['products']).to be_an(Array)
    end

    it 'returns limited products (max 10)' do
      # Create 15 products
      15.times { create(:product, category: category) }

      get :show, params: { id: category.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['products'].length).to be <= 10
    end

    context 'with non-existent category' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Category not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_category_params) do
      {
        category: {
          name: 'New Category',
          description: 'Category description'
        }
      }
    end

    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'creates category successfully' do
        post :create, params: valid_category_params

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Category created successfully')
        expect(json_response['data']['category']).to be_present
        expect(json_response['data']['category']['name']).to eq('New Category')
      end

      it 'returns error for invalid parameters' do
        post :create, params: {
          category: {
            name: '' # Invalid: name is required
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Category could not be created')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :create, params: valid_category_params

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
      end

      it 'updates category successfully' do
        patch :update, params: {
          id: category.id,
          category: {
            name: 'Updated Category Name',
            description: 'Updated description'
          }
        }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Category updated successfully')
        expect(category.reload.name).to eq('Updated Category Name')
      end

      it 'returns error for invalid parameters' do
        patch :update, params: {
          id: category.id,
          category: {
            name: '' # Invalid: name cannot be blank
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        patch :update, params: {
          id: category.id,
          category: { name: 'Updated Name' }
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

      it 'deletes category successfully' do
        delete :destroy, params: { id: category.id }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Category deleted successfully')
        expect(Category.find_by(id: category.id)).to be_nil
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        delete :destroy, params: { id: category.id }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
