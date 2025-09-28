require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      product = build(:product, brand: brand, category: category)
      expect(product).to be_valid
    end

    it 'is invalid without a name' do
      product = build(:product, name: nil, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with name too short' do
      product = build(:product, name: 'A', brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('is too short (minimum is 2 characters)')
    end

    it 'is invalid with name too long' do
      product = build(:product, name: 'A' * 101, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('is too long (maximum is 100 characters)')
    end

    it 'is invalid without a description' do
      product = build(:product, description: nil, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:description]).to include("can't be blank")
    end

    it 'is invalid with description too short' do
      product = build(:product, description: 'Short', brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:description]).to include('is too short (minimum is 10 characters)')
    end

    it 'is invalid without a price' do
      product = build(:product, price: nil, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include("can't be blank")
    end

    it 'is invalid with negative price' do
      product = build(:product, price: -100, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include('must be greater than 0')
    end

    it 'is invalid without stock quantity' do
      product = build(:product, stock_quantity: nil, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:stock_quantity]).to include("can't be blank")
    end

    it 'is invalid with negative stock quantity' do
      product = build(:product, stock_quantity: -1, brand: brand, category: category)
      expect(product).not_to be_valid
      expect(product.errors[:stock_quantity]).to include('must be greater than or equal to 0')
    end
  end

  describe 'associations' do
    it 'belongs to a brand' do
      product = create(:product, brand: brand, category: category)
      expect(product.brand).to eq(brand)
    end

    it 'belongs to a category' do
      product = create(:product, brand: brand, category: category)
      expect(product.category).to eq(category)
    end

    it 'has many order items' do
      product = create(:product, brand: brand, category: category)
      order = create(:order)
      order_item = create(:order_item, order: order, product: product)
      expect(product.order_items).to include(order_item)
    end

    it 'has many orders through order items' do
      product = create(:product, brand: brand, category: category)
      order = create(:order)
      create(:order_item, order: order, product: product)
      expect(product.orders).to include(order)
    end
  end

  describe 'scopes' do
    let!(:product1) { create(:product, stock_quantity: 5, price: 500, brand: brand, category: category) }
    let!(:product2) { create(:product, stock_quantity: 0, price: 800, brand: brand, category: category) }
    let!(:product3) { create(:product, stock_quantity: 10, price: 1500, brand: brand, category: category) }

    it 'returns available products' do
      available_products = Product.available
      expect(available_products).to include(product1, product3)
      expect(available_products).not_to include(product2)
    end

    it 'returns expensive products' do
      expensive_products = Product.expensive
      expect(expensive_products).to include(product3)
      expect(expensive_products).not_to include(product1, product2)
    end
  end

  describe 'methods' do
    let(:product) { create(:product, stock_quantity: 10, brand: brand, category: category) }

    it 'returns true when in stock' do
      expect(product.in_stock?).to be true
    end

    it 'returns false when out of stock' do
      product.update(stock_quantity: 0)
      expect(product.in_stock?).to be false
    end

    it 'reduces stock quantity' do
      product.reduce_stock(3)
      expect(product.stock_quantity).to eq(7)
    end
  end
end
