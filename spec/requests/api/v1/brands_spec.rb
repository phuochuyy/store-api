require 'rails_helper'

RSpec.describe 'Api::V1::Brands', type: :request do
  let!(:admin_user) { create(:user, role: 'admin') }
  let!(:customer_user) { create(:user, role: 'customer') }

  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  let(:valid_brand_params) do
    {
      brand: {
        name: 'Test Brand',
        description: 'A test brand for testing purposes'
      }
    }
  end

  describe 'GET /api/v1/brands' do
    let!(:brands) { create_list(:brand, 3) }

    it 'returns all brands' do
      get '/api/v1/brands', headers: { 'Authorization' => "Bearer #{admin_token}" }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['success']).to be true
      expect(json_response['data']['brands']).to be_an(Array)
      expect(json_response['data']['brands'].length).to eq(3)
      expect(json_response['data']['brands'].first).to include('id', 'name', 'description')
    end

    it 'supports pagination' do
      get '/api/v1/brands', params: { page: 1, per_page: 2 }, headers: { 'Authorization' => "Bearer #{admin_token}" }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response['data']['brands'].length).to eq(2)
      expect(json_response['data']['pagination']).to be_present
    end
  end

  describe 'GET /api/v1/brands/:id' do
    let!(:brand) { create(:brand, name: 'Test Brand', description: 'Test Description') }

    context 'with valid brand id' do
      it 'returns brand details' do
        get "/api/v1/brands/#{brand.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']['brand']['id']).to eq(brand.id)
        expect(json_response['data']['brand']['name']).to eq('Test Brand')
        expect(json_response['data']['brand']['description']).to eq('Test Description')
      end
    end

    context 'with invalid brand id' do
      it 'returns not found' do
        get '/api/v1/brands/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Record not found')
      end
    end
  end

  describe 'POST /api/v1/brands' do
    context 'as admin' do
      it 'creates a new brand' do
        expect do
          post '/api/v1/brands', params: valid_brand_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Brand, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']['name']).to eq('Test Brand')
        expect(json_response['data']['description']).to eq('A test brand for testing purposes')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post '/api/v1/brands', params: valid_brand_params, headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Access denied')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/brands', params: valid_brand_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          brand: {
            name: '',
            description: 'Test Description'
          }
        }
      end

      it 'returns validation errors' do
        post '/api/v1/brands', params: invalid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Validation failed')
      end
    end

    context 'with duplicate name' do
      let!(:existing_brand) { create(:brand, name: 'Existing Brand') }
      let(:duplicate_params) do
        {
          brand: {
            name: 'Existing Brand',
            description: 'Different description'
          }
        }
      end

      it 'returns validation error for duplicate name' do
        post '/api/v1/brands', params: duplicate_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'PUT /api/v1/brands/:id' do
    let!(:brand) { create(:brand, name: 'Original Name', description: 'Original Description') }
    let(:update_params) do
      {
        brand: {
          name: 'Updated Name',
          description: 'Updated Description'
        }
      }
    end

    context 'as admin' do
      it 'updates the brand' do
        put "/api/v1/brands/#{brand.id}", params: update_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response['success']).to be true
        expect(json_response['data']['name']).to eq('Updated Name')
        expect(json_response['data']['description']).to eq('Updated Description')

        brand.reload
        expect(brand.name).to eq('Updated Name')
        expect(brand.description).to eq('Updated Description')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        put "/api/v1/brands/#{brand.id}", params: update_params,
                                          headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid brand id' do
      it 'returns not found' do
        put '/api/v1/brands/99999', params: update_params, headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/brands/:id' do
    let!(:brand) { create(:brand) }

    context 'as admin' do
      it 'deletes the brand' do
        expect do
          delete "/api/v1/brands/#{brand.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        end.to change(Brand, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Brand deleted successfully')
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        delete "/api/v1/brands/#{brand.id}", headers: { 'Authorization' => "Bearer #{customer_token}" }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid brand id' do
      it 'returns not found' do
        delete '/api/v1/brands/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when brand has associated phones' do
      let!(:phone) { create(:phone, brand: brand) }

      it 'prevents deletion of brand with phones' do
        delete "/api/v1/brands/#{brand.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end
end
