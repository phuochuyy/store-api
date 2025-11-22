require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Brand, type: :model do
  describe 'associations' do
    it { should have_many(:products).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:brand) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(50) }

    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_least(10).is_at_most(500) }

    context 'name validation' do
      it 'accepts valid name length' do
        brand = build(:brand, name: 'Valid Brand Name')
        expect(brand).to be_valid
      end

      it 'rejects name shorter than 2 characters' do
        brand = build(:brand, name: 'A')
        expect(brand).not_to be_valid
        expect(brand.errors[:name]).to be_present
      end

      it 'rejects name longer than 50 characters' do
        brand = build(:brand, name: 'A' * 51)
        expect(brand).not_to be_valid
        expect(brand.errors[:name]).to be_present
      end

      it 'rejects duplicate name' do
        create(:brand, name: 'Unique Brand')
        duplicate_brand = build(:brand, name: 'Unique Brand')
        expect(duplicate_brand).not_to be_valid
        expect(duplicate_brand.errors[:name]).to include('has already been taken')
      end
    end

    context 'description validation' do
      it 'accepts valid description length' do
        brand = build(:brand, description: 'This is a valid description that meets the minimum length requirement')
        expect(brand).to be_valid
      end

      it 'rejects description shorter than 10 characters' do
        brand = build(:brand, description: 'Short')
        expect(brand).not_to be_valid
        expect(brand.errors[:description]).to be_present
      end

      it 'rejects description longer than 500 characters' do
        brand = build(:brand, description: 'A' * 501)
        expect(brand).not_to be_valid
        expect(brand.errors[:description]).to be_present
      end
    end
  end

  describe 'scopes' do
    describe '.with_products' do
      let!(:brand_with_products) { create(:brand) }
      let!(:brand_without_products) { create(:brand) }
      let!(:product) { create(:product, brand: brand_with_products) }

      it 'returns only brands that have products' do
        brands_with_products = Brand.with_products.to_a
        expect(brands_with_products).to include(brand_with_products)
        expect(brands_with_products).not_to include(brand_without_products)
      end

      it 'returns distinct brands' do
        # Create another product for the same brand
        create(:product, brand: brand_with_products)
        # Should still return only 1 brand (distinct)
        brands_with_products = Brand.with_products
        expect(brands_with_products.count).to eq(1)
        expect(brands_with_products.pluck(:id)).to contain_exactly(brand_with_products.id)
      end
    end
  end

  describe 'callbacks' do
    describe 'dependent destroy' do
      it 'destroys associated products when brand is destroyed' do
        brand = create(:brand)
        category = create(:category)
        product1 = create(:product, brand: brand, category: category)
        product2 = create(:product, brand: brand, category: category)

        product1_id = product1.id
        product2_id = product2.id

        expect { brand.destroy }.to change { Product.count }.by(-2)
        expect(Product.find_by(id: product1_id)).to be_nil
        expect(Product.find_by(id: product2_id)).to be_nil
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
