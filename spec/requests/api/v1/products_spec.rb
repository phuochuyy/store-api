require 'rails_helper'

RSpec.describe 'Api::V1::Products', type: :request do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:admin_token) { JwtEncodeService.encode(admin_user) }
  let(:customer_token) { JwtEncodeService.encode(customer_user) }

  describe 'GET /api/v1/products' do
    let!(:products) { create_list(:product, 3, brand: brand, category: category) }

    it 'returns all products' do
      get '/api/v1/products', headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].length).to eq(3)
    end

    it 'filters products by brand' do
      other_brand = create(:brand)
      create(:product, brand: other_brand, category: category)

      get '/api/v1/products', params: { brand_id: brand.id }, headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].length).to eq(3)
      expect(json_response['data']['products'].map { |p| p['brand']['id'] }).to all(eq(brand.id))
    end

    it 'searches products by name' do
      create(:product, name: 'iPhone 15', brand: brand, category: category)

      get '/api/v1/products', params: { search: 'iPhone' }, headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].length).to eq(1)
      expect(json_response['data']['products'].map { |p| p['name'] }).to include('iPhone 15')
    end

    it 'filters products by price range' do
      create(:product, price: 500, brand: brand, category: category)
      create(:product, price: 1500, brand: brand, category: category)

      get '/api/v1/products', params: { min_price: 400, max_price: 600 },
                              headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].count).to eq(1)
    end

    it 'filters products by stock availability' do
      create(:product, stock_quantity: 0, brand: brand, category: category)

      get '/api/v1/products', params: { in_stock: true }, headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].all? { |p| p['in_stock'] }).to be true
    end

    it 'returns paginated results' do
      get '/api/v1/products', params: { page: 1, per_page: 2 }, headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['products'].length).to eq(2)
      expect(json_response['data']['pagination']).to be_present
    end
  end

  describe 'GET /api/v1/products/:id' do
    let!(:product) { create(:product, brand: brand, category: category) }

    it 'returns a specific product' do
      get "/api/v1/products/#{product.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      expect(json_response['data']['product']['id']).to eq(product.id)
      expect(json_response['data']['product']['name']).to eq(product.name)
    end

    it 'returns 404 for non-existent product' do
      get '/api/v1/products/99999', headers: { 'Authorization' => "Bearer #{admin_token}" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/products' do
    let(:valid_params) do
      {
        product: {
          name: 'Test Product',
          description: 'A test product for demo purposes',
          price: 299.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        }
      }
    end

    context 'as admin' do
      it 'creates a new product' do
        post '/api/v1/products', params: valid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:created)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Product created successfully')
        expect(json_response['data']['name']).to eq('Test Product')
      end

      it 'returns validation errors for invalid data' do
        invalid_params = valid_params.dup
        invalid_params[:product][:name] = ''

        post '/api/v1/products', params: invalid_params, headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        post '/api/v1/products', params: valid_params, headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/products', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/products/:id' do
    let!(:product) { create(:product, brand: brand, category: category) }
    let(:update_params) do
      {
        product: {
          name: 'Updated Product Name',
          description: 'Updated product description',
          price: 399.99,
          stock_quantity: 15,
          brand_id: brand.id,
          category_id: category.id
        }
      }
    end

    context 'as admin' do
      it 'updates the product' do
        put "/api/v1/products/#{product.id}", params: update_params,
                                              headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:ok)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Product updated successfully')
        expect(json_response['data']['name']).to eq('Updated Product Name')
        expect(json_response['data']['price'].to_f).to eq(399.99)
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        put "/api/v1/products/#{product.id}", params: update_params,
                                              headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/products/:id' do
    let!(:product) { create(:product, brand: brand, category: category) }

    context 'as admin' do
      it 'deletes the product' do
        delete "/api/v1/products/#{product.id}", headers: { 'Authorization' => "Bearer #{admin_token}" }
        expect(response).to have_http_status(:ok)

        json_response = response.parsed_body
        expect(json_response['message']).to eq('Product deleted successfully')
        expect(Product.find_by(id: product.id)).to be_nil
      end
    end

    context 'as customer' do
      it 'returns forbidden' do
        delete "/api/v1/products/#{product.id}", headers: { 'Authorization' => "Bearer #{customer_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
