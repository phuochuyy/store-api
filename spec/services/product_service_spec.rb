require 'rails_helper'

RSpec.describe Products::ProductService, type: :service do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:valid_product_params) do
    {
      name: 'iPhone 15',
      description: 'Latest iPhone model',
      price: 999.99,
      stock_quantity: 10,
      brand_id: brand.id,
      category_id: category.id
    }
  end

  describe '.create_product' do
    context 'with valid parameters' do
      it 'creates a new product and returns success' do
        result = Products::ProductService.create_product(valid_product_params)

        expect(result[:product]).to be_present
        expect(result[:product][:name]).to eq('iPhone 15')
        expect(result[:product][:price]).to eq(999.99)
        expect(result[:product][:stock_quantity]).to eq(10)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing name' do
        invalid_params = valid_product_params.dup
        invalid_params[:name] = nil

        result = Products::ProductService.create_product(invalid_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Name can't be blank")
      end

      it 'returns error for missing description' do
        invalid_params = valid_product_params.dup
        invalid_params[:description] = nil

        result = Products::ProductService.create_product(invalid_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Description can't be blank")
      end

      it 'returns error for invalid price' do
        invalid_params = valid_product_params.dup
        invalid_params[:price] = -100

        result = Products::ProductService.create_product(invalid_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Price must be greater than 0')
      end
    end
  end

  describe '.update_product' do
    let!(:product) { create(:product, brand: brand, category: category) }

    context 'with valid parameters' do
      it 'updates the product and returns success' do
        update_params = { name: 'Updated iPhone 15', price: 1099.99 }

        result = Products::ProductService.update_product(product.id, update_params)

        expect(result[:success]).to be true
        expect(result[:product][:name]).to eq('Updated iPhone 15')
        expect(result[:product][:price]).to eq(1099.99)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid data' do
        invalid_params = { name: '', price: -100 }

        result = Products::ProductService.update_product(product.id, invalid_params)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end

    context 'with non-existent product' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Products::ProductService.update_product(99_999, valid_product_params)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.delete_product' do
    let!(:product) { create(:product, brand: brand, category: category) }

    context 'with product without order items' do
      it 'deletes the product and returns success' do
        result = Products::ProductService.delete_product(product.id)

        expect(result[:success]).to be true
        expect(Product.find_by(id: product.id)).to be_nil
      end
    end

    context 'with product having order items' do
      let!(:order) { create(:order) }
      let!(:order_item) { create(:order_item, order: order, product: product) }

      it 'returns error and does not delete the product' do
        result = Products::ProductService.delete_product(product.id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Cannot delete product with existing order items')
        expect(Product.find_by(id: product.id)).to be_present
      end
    end

    context 'with non-existent product' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Products::ProductService.delete_product(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.find_product' do
    let!(:product) { create(:product, brand: brand, category: category) }

    it 'returns product with related products' do
      result = Products::ProductService.find_product(product.id)

      expect(result[:product]).to be_present
      expect(result[:product][:id]).to eq(product.id)
      expect(result[:related_products]).to be_an(Array)
    end

    context 'with non-existent product' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Products::ProductService.find_product(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.list_products' do
    let!(:product1) do
      create(:product, name: 'iPhone 15', price: 999.99, stock_quantity: 10, brand: brand, category: category)
    end
    let!(:product2) do
      create(:product, name: 'Samsung Galaxy', price: 899.99, stock_quantity: 5, brand: brand, category: category)
    end
    let!(:product3) do
      create(:product, name: 'Out of Stock', price: 799.99, stock_quantity: 0, brand: brand, category: category)
    end

    it 'returns all products with pagination' do
      result = Products::ProductService.list_products

      expect(result[:products]).to be_an(Array)
      expect(result[:products].length).to eq(3)
      expect(result[:pagination]).to be_present
      expect(result[:pagination][:current_page]).to eq(1)
    end

    context 'with search filter' do
      it 'filters products by name' do
        result = Products::ProductService.list_products(filters: { search: 'iPhone' })

        expect(result[:products].count).to eq(1)
        expect(result[:products].first[:name]).to eq('iPhone 15')
      end
    end

    context 'with price range filter' do
      it 'filters products by price range' do
        result = Products::ProductService.list_products(filters: { min_price: 900, max_price: 1000 })

        expect(result[:products].count).to eq(1)
        expect(result[:products].first[:name]).to eq('iPhone 15')
      end
    end

    context 'with stock filter' do
      it 'returns only products in stock' do
        result = Products::ProductService.list_products(filters: { in_stock: true })

        expect(result[:products].count).to eq(2)
        expect(result[:products].map { |p| p[:name] }).not_to include('Out of Stock')
      end
    end

    context 'with pagination' do
      it 'returns paginated results' do
        result = Products::ProductService.list_products(pagination: { page: 1, per_page: 2 })

        expect(result[:products].length).to eq(2)
        expect(result[:pagination][:per_page]).to eq(2)
      end
    end
  end
end
