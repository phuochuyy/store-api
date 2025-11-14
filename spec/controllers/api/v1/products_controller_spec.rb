require 'rails_helper'

RSpec.describe Api::V1::ProductsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:product) { create(:product, brand: brand, category: category) }
  let(:valid_token) do
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
  let(:admin_token) do
    payload = {
      user_id: admin_user.id,
      email: admin_user.email,
      role: admin_user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end

  before do
    request.headers['Content-Type'] = 'application/json'
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns success with products list' do
        create_list(:product, 3, brand: brand, category: category)
        get :index

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Products retrieved successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('products', 'pagination')
      end

      it 'returns paginated products' do
        create_list(:product, 15, brand: brand, category: category)
        get :index, params: { page: 1, per_page: 10 }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].length).to eq(10)
        expect(response_data['pagination']).to include(
          'current_page' => 1,
          'per_page' => 10
        )
      end

      it 'filters products by brand_id' do
        brand2 = create(:brand)
        create(:product, brand: brand, category: category)
        create(:product, brand: brand2, category: category)

        get :index, params: { brand_id: brand.id }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].all? { |p| p['brand']['id'] == brand.id }).to be true
      end

      it 'filters products by category_id' do
        category2 = create(:category)
        create(:product, brand: brand, category: category)
        create(:product, brand: brand, category: category2)

        get :index, params: { category_id: category.id }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].all? { |p| p['category']['id'] == category.id }).to be true
      end

      it 'filters products by min_price' do
        create(:product, brand: brand, category: category, price: 50.00)
        create(:product, brand: brand, category: category, price: 150.00)

        get :index, params: { min_price: 100.00 }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].all? { |p| p['price'].to_f >= 100.00 }).to be true
      end

      it 'filters products by max_price' do
        create(:product, brand: brand, category: category, price: 50.00)
        create(:product, brand: brand, category: category, price: 150.00)

        get :index, params: { max_price: 100.00 }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].all? { |p| p['price'].to_f <= 100.00 }).to be true
      end

      it 'filters products by in_stock' do
        create(:product, brand: brand, category: category, stock_quantity: 10)
        create(:product, brand: brand, category: category, stock_quantity: 0)

        get :index, params: { in_stock: true }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].all? { |p| p['stock_quantity'] > 0 }).to be true
      end

      it 'filters products by search term' do
        create(:product, brand: brand, category: category, name: 'iPhone 15')
        create(:product, brand: brand, category: category, name: 'Samsung Galaxy')

        get :index, params: { search: 'iPhone' }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].any? { |p| p['name'].include?('iPhone') }).to be true
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
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

      it 'returns success with product details' do
        get :show, params: { id: product.id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Product retrieved successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('product', 'related_products')
      end

      it 'returns product with correct attributes' do
        get :show, params: { id: product.id }

        product_data = JSON.parse(response.body)['data']['product']
        expect(product_data).to include(
          'id' => product.id,
          'name' => product.name,
          'description' => product.description,
          'price' => product.price.to_s
        )
      end

      it 'returns not found for non-existent product' do
        get :show, params: { id: 99_999 }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Product not found'
        )
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get :show, params: { id: product.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #search' do
    context 'when authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns success with search results' do
        create(:product, brand: brand, category: category, name: 'iPhone 15 Pro')
        create(:product, brand: brand, category: category, name: 'Samsung Galaxy S24')

        get :search, params: { search: 'iPhone' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Products search completed successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('products', 'pagination', 'search_query')
      end

      it 'searches in product name, description, brand, and category' do
        brand2 = create(:brand, name: 'Apple')
        create(:product, brand: brand2, category: category, name: 'iPhone', description: 'Premium phone')

        get :search, params: { search: 'Apple' }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products'].length).to be > 0
      end

      it 'returns empty results for no matches' do
        get :search, params: { search: 'NonExistentProduct123' }

        response_data = JSON.parse(response.body)['data']
        expect(response_data['products']).to be_empty
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get :search, params: { search: 'test' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_product_params) do
      {
        product: {
          name: 'New Product',
          description: 'This is a valid product description that meets the minimum length requirement',
          price: 199.99,
          stock_quantity: 50,
          brand_id: brand.id,
          category_id: category.id,
          specifications: '{"color": "black", "storage": "256GB"}'
        }
      }
    end

    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'creates a new product with valid params' do
        post :create, params: valid_product_params

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Product created successfully'
        )
        expect(Product.count).to eq(1)
      end

      it 'returns created product data' do
        post :create, params: valid_product_params

        product_data = JSON.parse(response.body)['data']['product']
        expect(product_data).to include(
          'name' => 'New Product',
          'price' => '199.99'
        )
      end

      it 'returns error for invalid params' do
        invalid_params = {
          product: {
            name: 'A', # Too short
            description: 'Short', # Too short
            price: -10, # Invalid
            stock_quantity: -5, # Invalid
            brand_id: brand.id,
            category_id: category.id
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
          product: {
            name: 'Product Name'
            # Missing other required fields
          }
        }

        post :create, params: incomplete_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for non-existent brand_id' do
        invalid_params = valid_product_params.deep_dup
        invalid_params[:product][:brand_id] = 99_999

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for non-existent category_id' do
        invalid_params = valid_product_params.deep_dup
        invalid_params[:product][:category_id] = 99_999

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for invalid JSON specifications' do
        invalid_params = valid_product_params.deep_dup
        invalid_params[:product][:specifications] = 'invalid json'

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        post :create, params: valid_product_params

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post :create, params: valid_product_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: product.id,
        product: {
          name: 'Updated Product Name',
          description: 'This is an updated product description that meets the minimum length requirement',
          price: 299.99,
          stock_quantity: 75
        }
      }
    end

    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'updates product with valid params' do
        patch :update, params: update_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Product updated successfully'
        )
        product.reload
        expect(product.name).to eq('Updated Product Name')
        expect(product.price).to eq(299.99)
      end

      it 'returns updated product data' do
        patch :update, params: update_params

        product_data = JSON.parse(response.body)['data']['product']
        expect(product_data['name']).to eq('Updated Product Name')
      end

      it 'returns error for invalid params' do
        invalid_params = update_params.deep_dup
        invalid_params[:product][:name] = 'A' # Too short
        invalid_params[:product][:price] = -10 # Invalid

        patch :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns not found for non-existent product' do
        patch :update, params: { id: 99_999, product: { name: 'Test' } }

        expect(response).to have_http_status(:not_found)
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
  end

  describe 'DELETE #destroy' do
    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'deletes product successfully' do
        product_to_delete = create(:product, brand: brand, category: category)
        product_id = product_to_delete.id

        delete :destroy, params: { id: product_id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Product deleted successfully'
        )
        expect(Product.find_by(id: product_id)).to be_nil
      end

      it 'returns error when product has order items' do
        product_with_orders = create(:product, brand: brand, category: category)
        # Simulate product having order items
        allow_any_instance_of(Product).to receive(:order_items).and_return(double(exists?: true))

        delete :destroy, params: { id: product_with_orders.id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to include('Cannot delete product')
      end

      it 'returns not found for non-existent product' do
        delete :destroy, params: { id: 99_999 }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        delete :destroy, params: { id: product.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete :destroy, params: { id: product.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #upload_image' do
    let(:image_file) do
      ActionDispatch::Http::UploadedFile.new(
        tempfile: StringIO.new('fake image content'),
        filename: 'test.jpg',
        type: 'image/jpeg'
      )
    end

    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'uploads image successfully' do
        product_without_image = create(:product, brand: brand, category: category)

        post :upload_image, params: { id: product_without_image.id, image: image_file }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Image uploaded successfully'
        )
        product_without_image.reload
        expect(product_without_image.image.attached?).to be true
      end

      it 'returns error when product already has image' do
        product_with_image = create(:product, :with_image, brand: brand, category: category)

        post :upload_image, params: { id: product_with_image.id, image: image_file }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to include('already has an image')
      end

      it 'returns not found for non-existent product' do
        post :upload_image, params: { id: 99_999, image: image_file }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        post :upload_image, params: { id: product.id, image: image_file }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post :upload_image, params: { id: product.id, image: image_file }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #remove_image' do
    context 'when authenticated as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
      end

      it 'removes image successfully' do
        product_with_image = create(:product, :with_image, brand: brand, category: category)

        delete :remove_image, params: { id: product_with_image.id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Image removed successfully'
        )
        product_with_image.reload
        expect(product_with_image.image.attached?).to be false
      end

      it 'returns error when product has no image' do
        product_without_image = create(:product, brand: brand, category: category)

        delete :remove_image, params: { id: product_without_image.id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to include('no image to remove')
      end

      it 'returns not found for non-existent product' do
        delete :remove_image, params: { id: 99_999 }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated as customer' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns forbidden' do
        delete :remove_image, params: { id: product.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete :remove_image, params: { id: product.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
