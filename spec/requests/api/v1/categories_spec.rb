require 'rails_helper'

RSpec.describe 'Api::V1::Categories', type: :request do
  let!(:admin_user) { create(:user, role: 'admin') }
  let!(:customer_user) { create(:user, role: 'customer') }

  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  let(:valid_category_params) do
    {
      category: {
        name: 'Test Category',
        description: 'A test category for testing purposes'
      }
    }
  end

  describe 'GET /api/v1/categories' do
    let!(:categories) { create_list(:category, 3) }

    it 'returns all categories' do
      get '/api/v1/categories', headers: { 'Authorization' => "Bearer #{admin_token}" }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['data']['categories']).to be_an(Array)
      expect(json_response['data']['categories'].length).to eq(3)
      expect(json_response['data']['categories'].first).to include('id', 'name', 'description')
    end

    it 'supports pagination' do
      get '/api/v1/categories', params: { page: 1, per_page: 2 },
                                headers: { 'Authorization' => "Bearer #{admin_token}" }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['categories'].length).to eq(2)
      expect(json_response['pagination']).to be_present
    end
  end

  describe 'GET /api/v1/categories/:id' do
    let!(:category) { create(:category, name: 'Test Category', description: 'Test Description') }

    context 'with valid category id' do
      it 'returns category details' do
        get "/api/v1/categories/#{category.id}", headers: { Authorization: "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['category']['id']).to eq(category.id)
        expect(json_response['category']['name']).to eq('Test Category')
        expect(json_response['category']['description']).to eq('Test Description')
      end
    end

    context 'with invalid category id' do
      it 'returns not found' do
        get '/api/v1/categories/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Record not found')
      end
    end
  end

  describe 'POST /api/v1/categories' do
    context 'as admin' do
      it 'creates a new category' do
        expect do
          post '/api/v1/categories', params: valid_category_params,
                                     headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Category, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['message']).to eq('Category created successfully')
        expect(json_response['category']['name']).to eq('Test Category')
        expect(json_response['category']['description']).to eq('A test category for testing purposes')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post '/api/v1/categories', params: valid_category_params,
                                   headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['error']).to eq('Admin access required')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/categories', params: valid_category_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          category: {
            name: '',
            description: 'Test Description'
          }
        }
      end

      it 'returns validation errors' do
        post '/api/v1/categories', params: invalid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end

    context 'with duplicate name' do
      let!(:existing_category) { create(:category, name: 'Existing Category') }
      let(:duplicate_params) do
        {
          category: {
            name: 'Existing Category',
            description: 'Different description'
          }
        }
      end

      it 'returns validation error for duplicate name' do
        post '/api/v1/categories', params: duplicate_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['errors']).to include('Name has already been taken')
      end
    end
  end

  describe 'PUT /api/v1/categories/:id' do
    let!(:category) { create(:category, name: 'Original Name', description: 'Original Description') }
    let(:update_params) do
      {
        category: {
          name: 'Updated Name',
          description: 'Updated Description'
        }
      }
    end

    context 'as admin' do
      it 'updates the category' do
        put "/api/v1/categories/#{category.id}", params: update_params,
                                                 headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['message']).to eq('Category updated successfully')
        expect(json_response['category']['name']).to eq('Updated Name')
        expect(json_response['category']['description']).to eq('Updated Description')

        category.reload
        expect(category.name).to eq('Updated Name')
        expect(category.description).to eq('Updated Description')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        put "/api/v1/categories/#{category.id}", params: update_params,
                                                 headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['error']).to eq('Admin access required')
      end
    end

    context 'with invalid category id' do
      it 'returns not found' do
        put '/api/v1/categories/99999', params: update_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/categories/:id' do
    let!(:category) { create(:category) }

    context 'as admin' do
      it 'deletes the category' do
        expect do
          delete "/api/v1/categories/#{category.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Category, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['message']).to eq('Category deleted successfully')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        delete "/api/v1/categories/#{category.id}", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['error']).to eq('Admin access required')
      end
    end

    context 'with invalid category id' do
      it 'returns not found' do
        delete '/api/v1/categories/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when category has associated phones' do
      let!(:phone) { create(:phone, category: category) }

      it 'deletes category and associated phones' do
        expect do
          delete "/api/v1/categories/#{category.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Category, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['message']).to eq('Category deleted successfully')
      end
    end
  end
end
