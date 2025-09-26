require 'rails_helper'

RSpec.describe Phone, type: :model do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      phone = build(:phone, brand: brand, category: category)
      expect(phone).to be_valid
    end

    it 'is invalid without a name' do
      phone = build(:phone, name: nil, brand: brand, category: category)
      expect(phone).not_to be_valid
      expect(phone.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with name too short' do
      phone = build(:phone, name: 'A', brand: brand, category: category)
      expect(phone).not_to be_valid
      expect(phone.errors[:name]).to include('is too short (minimum is 2 characters)')
    end

    it 'is invalid with negative price' do
      phone = build(:phone, price: -100, brand: brand, category: category)
      expect(phone).not_to be_valid
      expect(phone.errors[:price]).to include('must be greater than 0')
    end

    it 'is invalid with negative stock quantity' do
      phone = build(:phone, stock_quantity: -1, brand: brand, category: category)
      expect(phone).not_to be_valid
      expect(phone.errors[:stock_quantity]).to include('must be greater than or equal to 0')
    end
  end

  describe 'associations' do
    it 'belongs to a brand' do
      phone = create(:phone, brand: brand, category: category)
      expect(phone.brand).to eq(brand)
    end

    it 'belongs to a category' do
      phone = create(:phone, brand: brand, category: category)
      expect(phone.category).to eq(category)
    end
  end

  describe 'scopes' do
    let!(:available_phone) { create(:phone, stock_quantity: 10, brand: brand, category: category) }
    let!(:unavailable_phone) { create(:phone, stock_quantity: 0, brand: brand, category: category) }

    it 'returns available phones' do
      expect(described_class.available).to include(available_phone)
      expect(described_class.available).not_to include(unavailable_phone)
    end

    it 'returns expensive phones' do
      expensive_phone = create(:phone, price: 1500, brand: brand, category: category)
      expect(described_class.expensive).to include(expensive_phone)
      expect(described_class.expensive).not_to include(available_phone)
    end
  end

  describe 'methods' do
    it 'returns true when in stock' do
      phone = create(:phone, stock_quantity: 5, brand: brand, category: category)
      expect(phone.in_stock?).to be true
    end

    it 'returns false when out of stock' do
      phone = create(:phone, stock_quantity: 0, brand: brand, category: category)
      expect(phone.in_stock?).to be false
    end

    it 'reduces stock quantity' do
      phone = create(:phone, stock_quantity: 10, brand: brand, category: category)
      phone.reduce_stock(3)
      expect(phone.stock_quantity).to eq(7)
    end
  end
end
