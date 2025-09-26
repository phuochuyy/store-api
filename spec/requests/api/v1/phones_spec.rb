require 'rails_helper'

RSpec.describe 'Api::V1::Phones', type: :request do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:admin_token) { JWTEncodeService.encode(admin_user) }
  let(:customer_token) { JWTEncodeService.encode(customer_user) }

  describe 'GET /api/v1/phones' do
    let!(:phones) { create_list(:phone, 3, brand: brand, category: category) }

    it 'returns all phones' do
      get '/api/v1/phones'
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['phones'].length).to eq(3)
    end

    it 'filters phones by brand' do
      other_brand = create(:brand)
      create(:phone, brand: other_brand, category: category)

      get '/api/v1/phones', params: { brand_id: brand.id }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['phones'].length).to eq(3)
      expect(json_response['phones'].map { |p| p['brand']['id'] }).to all(eq(brand.id))
    end

    it 'searches phones by name' do
      create(:phone, name: 'iPhone 15', brand: brand, category: category)

      get '/api/v1/phones', params: { search: 'iPhone' }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['phones'].length).to eq(1)
      expect(json_response['phones'].first['name']).to eq('iPhone 15')
    end
  end

  describe 'GET /api/v1/phones/:id' do
    let!(:phone) { create(:phone, brand: brand, category: category) }

    it 'returns a specific phone' do
      get "/api/v1/phones/#{phone.id}"
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['phone']['id']).to eq(phone.id)
      expect(json_response['phone']['name']).to eq(phone.name)
    end

    it 'returns 404 for non-existent phone' do
      get '/api/v1/phones/99999'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/phones' do
    let(:valid_params) do
      {
        phone: {
          name: 'Test Phone',
          description: 'A test phone for demo purposes',
          price: 299.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        }
      }
    end

    context 'as admin' do
      it 'creates a new phone' do
        post '/api/v1/phones', params: valid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:created)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Phone created successfully')
        expect(json_response['phone']['name']).to eq('Test Phone')
      end

      it 'returns validation errors for invalid data' do
        invalid_params = valid_params.dup
        invalid_params[:phone][:name] = ''

        post '/api/v1/phones', params: invalid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:unprocessable_entity)

        json_response = response.parsed_body
        expect(json_response['error']).to eq('Validation failed')
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post '/api/v1/phones', params: valid_params, headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/phones', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/phones/:id' do
    let!(:phone) { create(:phone, brand: brand, category: category) }
    let(:update_params) do
      {
        phone: {
          name: 'Updated Phone Name',
          price: 399.99
        }
      }
    end

    context 'as admin' do
      it 'updates the phone' do
        put "/api/v1/phones/#{phone.id}", params: update_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:ok)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Phone updated successfully')
        expect(json_response['phone']['name']).to eq('Updated Phone Name')
        expect(json_response['phone']['price']).to eq(399.99)
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        put "/api/v1/phones/#{phone.id}", params: update_params,
                                          headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/phones/:id' do
    let!(:phone) { create(:phone, brand: brand, category: category) }

    context 'as admin' do
      it 'deletes the phone' do
        delete "/api/v1/phones/#{phone.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:ok)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Phone deleted successfully')
        expect(Phone.find_by(id: phone.id)).to be_nil
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        delete "/api/v1/phones/#{phone.id}", headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
