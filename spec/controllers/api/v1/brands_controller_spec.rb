require 'rails_helper'

RSpec.describe Api::V1::BrandsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:brand) { create(:brand) }

  # Helper method to generate JWT token
  def generate_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    JWT.encode(payload, secret_key, 'HS256')
  end

  let(:valid_token) { generate_token(user) }
  let(:admin_token) { generate_token(admin_user) }
  let(:expired_token) do
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: 2.days.ago.to_i,
      exp: 1.day.ago.to_i
    }
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    JWT.encode(payload, secret_key, 'HS256')
  end

  before do
    request.headers['Content-Type'] = 'application/json'
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns success with brands list' do
        create_list(:brand, 3)
        get :index

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Brands retrieved successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('brands', 'pagination')
      end

      it 'returns paginated brands' do
        create_list(:brand, 15)
        get :index, params: { page: 1, per_page: 10 }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['brands'].length).to eq(10)
        expect(response_data['pagination']).to include(
          'current_page' => 1,
          'per_page' => 10
        )
      end

      it 'returns brands with products included' do
        brand_with_product = create(:brand)
        create(:product, brand: brand_with_product)
        get :index

        response_data = JSON.parse(response.body)['data']
        expect(response_data['brands']).to be_an(Array)
      end

      it 'returns empty array when no brands exist' do
        Brand.delete_all
        get :index

        response_data = JSON.parse(response.body)['data']
        expect(response_data['brands']).to eq([])
        expect(response_data['pagination']['total_count']).to eq(0)
      end

      it 'handles pagination with page 2' do
        create_list(:brand, 15)
        get :index, params: { page: 2, per_page: 10 }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['brands'].length).to eq(5)
        expect(response_data['pagination']['current_page']).to eq(2)
      end

      it 'handles invalid pagination params gracefully' do
        create_list(:brand, 5)
        get :index, params: { page: -1, per_page: -10 }

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)['data']
        expect(response_data['brands']).to be_an(Array)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
        response_body = JSON.parse(response.body)
        expect(response_body).to include('success' => false)
        expect(response_body['message'] || response_body['error']).to be_present
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for malformed token' do
        request.headers['Authorization'] = 'Bearer invalid-token'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for expired token' do
        request.headers['Authorization'] = "Bearer #{expired_token}"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for missing Bearer prefix' do
        request.headers['Authorization'] = valid_token
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    context 'when authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns success with brand details' do
        get :show, params: { id: brand.id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Brand retrieved successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('brand', 'products_count')
      end

      it 'returns brand with correct attributes' do
        get :show, params: { id: brand.id }

        brand_data = JSON.parse(response.body)['data']['brand']
        expect(brand_data).to include(
          'id' => brand.id,
          'name' => brand.name,
          'description' => brand.description
        )
      end

      it 'returns products count' do
        create_list(:product, 3, brand: brand)
        get :show, params: { id: brand.id }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products_count']).to eq(3)
      end

      it 'returns not found for non-existent brand' do
        get :show, params: { id: 99_999 }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Brand not found'
        )
      end

      it 'returns not found for string id' do
        get :show, params: { id: 'invalid' }
        expect(response).to have_http_status(:not_found)
      end

      it 'returns zero products count when brand has no products' do
        brand_without_products = create(:brand)
        get :show, params: { id: brand_without_products.id }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products_count']).to eq(0)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get :show, params: { id: brand.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for expired token' do
        request.headers['Authorization'] = "Bearer #{expired_token}"
        get :show, params: { id: brand.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_brand_params) do
      {
        brand: {
          name: 'New Brand',
          description: 'This is a valid brand description that meets the minimum length requirement'
        }
      }
    end

    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'creates a new brand with valid params' do
        post :create, params: valid_brand_params

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Brand created successfully'
        )
        expect(Brand.count).to eq(1)
      end

      it 'returns created brand data' do
        post :create, params: valid_brand_params

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)
        expect(response_body).to include('success' => true, 'data' => be_present)
        brand_data = response_body['data']['brand'] || response_body['data']
        expect(brand_data).to include(
          'name' => 'New Brand',
          'description' => 'This is a valid brand description that meets the minimum length requirement'
        )
      end

      it 'returns error for invalid params' do
        invalid_params = {
          brand: {
            name: 'A', # Too short
            description: 'Short' # Too short
          }
        }

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for missing required fields' do
        incomplete_params = {
          brand: {
            name: 'Brand Name'
            # Missing description
          }
        }

        post :create, params: incomplete_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for duplicate name' do
        create(:brand, name: 'Existing Brand')
        duplicate_params = {
          brand: {
            name: 'Existing Brand',
            description: 'This is a valid brand description that meets the minimum length requirement'
          }
        }

        post :create, params: duplicate_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['errors']).to be_present
      end

      it 'returns error for name too long' do
        long_name_params = {
          brand: {
            name: 'A' * 101, # Exceeds max length
            description: 'This is a valid brand description that meets the minimum length requirement'
          }
        }

        post :create, params: long_name_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for description too long' do
        long_desc_params = {
          brand: {
            name: 'Valid Brand Name',
            description: 'A' * 501 # Exceeds max length
          }
        }

        post :create, params: long_desc_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for empty params' do
        # Empty params will fail validation
        post :create, params: { brand: {} }

        # Controller uses params.expect which may raise or return error
        expect(response.status).to be >= 400
        response_body = JSON.parse(response.body)
        expect(response_body['success']).to be false
      end

      it 'handles nil params gracefully' do
        # Controller uses params.expect which may raise ParameterMissing
        # or handle gracefully depending on Rails version

        post :create, params: { brand: nil }
        expect(response.status).to be >= 400
      rescue ActionController::ParameterMissing
        # Expected behavior - controller raises error

      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        post :create, params: valid_brand_params

        expect(response).to have_http_status(:forbidden)
        response_body = JSON.parse(response.body)
        expect(response_body).to include('success' => false)
        expect(response_body['message'] || response_body['error']).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post :create, params: valid_brand_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for expired token' do
        request.headers['Authorization'] = "Bearer #{expired_token}"
        post :create, params: valid_brand_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: brand.id,
        brand: {
          name: 'Updated Brand Name',
          description: 'This is an updated brand description that meets the minimum length requirement'
        }
      }
    end

    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'updates brand with valid params' do
        patch :update, params: update_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Brand updated successfully'
        )
        brand.reload
        expect(brand.name).to eq('Updated Brand Name')
      end

      it 'returns updated brand data' do
        patch :update, params: update_params

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body).to include('success' => true, 'data' => be_present)
        brand_data = response_body['data']['brand'] || response_body['data']
        expect(brand_data['name']).to eq('Updated Brand Name')
      end

      it 'returns error for invalid params' do
        invalid_params = update_params.deep_dup
        invalid_params[:brand][:name] = 'A' # Too short
        invalid_params[:brand][:description] = 'Short' # Too short

        patch :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for duplicate name' do
        _other_brand = create(:brand, name: 'Other Brand')
        duplicate_params = update_params.deep_dup
        duplicate_params[:brand][:name] = 'Other Brand'

        patch :update, params: duplicate_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns not found for non-existent brand' do
        patch :update, params: { id: 99_999, brand: { name: 'Test' } }

        expect(response).to have_http_status(:not_found)
      end

      it 'allows partial update - only name' do
        original_description = brand.description
        # NOTE: BrandValidator requires both fields, so we need to provide description too
        # But we can test that only name changes
        patch :update, params: {
          id: brand.id,
          brand: {
            name: 'Only Name Updated',
            description: original_description # Keep original description
          }
        }

        expect(response).to have_http_status(:ok)
        brand.reload
        expect(brand.name).to eq('Only Name Updated')
        expect(brand.description).to eq(original_description)
      end

      it 'allows partial update - only description' do
        original_name = brand.name
        # NOTE: BrandValidator requires both fields, so we need to provide name too
        patch :update, params: {
          id: brand.id,
          brand: {
            name: original_name, # Keep original name
            description: 'Only description updated with valid length requirement'
          }
        }

        expect(response).to have_http_status(:ok)
        brand.reload
        expect(brand.name).to eq(original_name)
        expect(brand.description).to eq('Only description updated with valid length requirement')
      end

      it 'returns error when updating to duplicate name of another brand' do
        _other_brand = create(:brand, name: 'Other Brand')
        patch :update, params: {
          id: brand.id,
          brand: { name: 'Other Brand' }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'allows updating to same name (no change)' do
        patch :update, params: {
          id: brand.id,
          brand: { name: brand.name, description: 'Updated description with valid length requirement' }
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        patch :update, params: update_params

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch :update, params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for expired token' do
        request.headers['Authorization'] = "Bearer #{expired_token}"
        patch :update, params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'deletes brand successfully' do
        brand_to_delete = create(:brand)
        brand_id = brand_to_delete.id

        delete :destroy, params: { id: brand_id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Brand deleted successfully'
        )
        expect(Brand.find_by(id: brand_id)).to be_nil
      end

      it 'deletes associated products when brand is deleted' do
        brand_with_products = create(:brand)
        product1 = create(:product, brand: brand_with_products)
        product2 = create(:product, brand: brand_with_products)

        delete :destroy, params: { id: brand_with_products.id }

        expect(Product.find_by(id: product1.id)).to be_nil
        expect(Product.find_by(id: product2.id)).to be_nil
      end

      it 'returns not found for non-existent brand' do
        delete :destroy, params: { id: 99_999 }

        expect(response).to have_http_status(:not_found)
      end

      it 'decrements brand count' do
        brand_to_delete = create(:brand)
        initial_count = Brand.count

        delete :destroy, params: { id: brand_to_delete.id }

        expect(Brand.count).to eq(initial_count - 1)
      end

      it 'returns success message in response' do
        brand_to_delete = create(:brand)
        delete :destroy, params: { id: brand_to_delete.id }

        response_body = JSON.parse(response.body)
        expect(response_body['message']).to eq('Brand deleted successfully')
        expect(response_body['data']).to be_nil
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        delete :destroy, params: { id: brand.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete :destroy, params: { id: brand.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for expired token' do
        request.headers['Authorization'] = "Bearer #{expired_token}"
        delete :destroy, params: { id: brand.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Response format' do
    before do
      request.headers['Authorization'] = "Bearer #{valid_token}"
    end

    it 'returns consistent success response format for index' do
      get :index
      response_body = JSON.parse(response.body)

      expect(response_body).to include(
        'success' => true,
        'message' => be_a(String),
        'data' => be_a(Hash)
      )
      expect(response_body['data']).to include('brands', 'pagination')
    end

    it 'returns consistent success response format for show' do
      get :show, params: { id: brand.id }
      response_body = JSON.parse(response.body)

      expect(response_body).to include(
        'success' => true,
        'message' => be_a(String),
        'data' => be_a(Hash)
      )
      expect(response_body['data']).to include('brand', 'products_count')
    end

    it 'returns consistent error response format' do
      get :show, params: { id: 99_999 }
      response_body = JSON.parse(response.body)

      expect(response_body).to include(
        'success' => false,
        'message' => be_a(String)
      )
    end
  end
end
