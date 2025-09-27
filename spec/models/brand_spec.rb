require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      brand = build(:brand)
      expect(brand).to be_valid
    end

    it 'is invalid without a name' do
      brand = build(:brand, name: nil)
      expect(brand).not_to be_valid
      expect(brand.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with name too short' do
      brand = build(:brand, name: 'A')
      expect(brand).not_to be_valid
      expect(brand.errors[:name]).to include('is too short (minimum is 2 characters)')
    end

    it 'is invalid with name too long' do
      brand = build(:brand, name: 'A' * 51)
      expect(brand).not_to be_valid
      expect(brand.errors[:name]).to include('is too long (maximum is 50 characters)')
    end

    it 'is invalid with duplicate name' do
      create(:brand, name: 'Apple')
      brand = build(:brand, name: 'Apple')
      expect(brand).not_to be_valid
      expect(brand.errors[:name]).to include('has already been taken')
    end

    it 'is valid with unique name' do
      create(:brand, name: 'Apple')
      brand = build(:brand, name: 'Samsung')
      expect(brand).to be_valid
    end
  end

  describe 'associations' do
    let(:brand) { create(:brand) }

    it 'has many phones' do
      expect(brand).to respond_to(:phones)
    end

    it 'destroys associated phones when destroyed' do
      phone = create(:phone, brand: brand)
      expect { brand.destroy }.to change(Phone, :count).by(-1)
    end
  end

  describe 'scopes' do
    let!(:brand1) { create(:brand, name: 'Apple') }
    let!(:brand2) { create(:brand, name: 'Samsung') }

    it 'orders by name alphabetically' do
      brands = Brand.all
      expect(brands.first).to eq(brand1)
      expect(brands.last).to eq(brand2)
    end
  end

  describe 'methods' do
    let(:brand) { create(:brand, name: 'Apple') }

    it 'has name attribute' do
      expect(brand.name).to eq('Apple')
    end
  end
end
