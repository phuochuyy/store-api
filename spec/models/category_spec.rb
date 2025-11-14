require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it { should have_many(:products).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:category) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(50) }

    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_least(10).is_at_most(500) }

    context 'name validation' do
      it 'accepts valid name length' do
        category = build(:category, name: 'Valid Category Name')
        expect(category).to be_valid
      end

      it 'rejects name shorter than 2 characters' do
        category = build(:category, name: 'A')
        expect(category).not_to be_valid
        expect(category.errors[:name]).to be_present
      end

      it 'rejects name longer than 50 characters' do
        category = build(:category, name: 'A' * 51)
        expect(category).not_to be_valid
        expect(category.errors[:name]).to be_present
      end

      it 'rejects duplicate name' do
        create(:category, name: 'Unique Category')
        duplicate_category = build(:category, name: 'Unique Category')
        expect(duplicate_category).not_to be_valid
        expect(duplicate_category.errors[:name]).to include('has already been taken')
      end
    end

    context 'description validation' do
      it 'accepts valid description length' do
        category = build(:category, description: 'This is a valid description that meets the minimum length requirement')
        expect(category).to be_valid
      end

      it 'rejects description shorter than 10 characters' do
        category = build(:category, description: 'Short')
        expect(category).not_to be_valid
        expect(category.errors[:description]).to be_present
      end

      it 'rejects description longer than 500 characters' do
        category = build(:category, description: 'A' * 501)
        expect(category).not_to be_valid
        expect(category.errors[:description]).to be_present
      end
    end
  end

  describe 'scopes' do
    describe '.with_products' do
      let!(:category_with_products) { create(:category) }
      let!(:category_without_products) { create(:category) }
      let!(:product) { create(:product, category: category_with_products) }

      it 'returns only categories that have products' do
        categories_with_products = Category.with_products.to_a
        expect(categories_with_products).to include(category_with_products)
        expect(categories_with_products).not_to include(category_without_products)
      end

      it 'returns distinct categories' do
        create(:product, category: category_with_products)
        categories_with_products = Category.with_products
        expect(categories_with_products.count).to eq(1)
        expect(categories_with_products.pluck(:id)).to contain_exactly(category_with_products.id)
      end
    end
  end

  describe 'callbacks' do
    describe 'dependent destroy' do
      it 'destroys associated products when category is destroyed' do
        category = create(:category)
        brand = create(:brand)
        product1 = create(:product, category: category, brand: brand)
        product2 = create(:product, category: category, brand: brand)

        product1_id = product1.id
        product2_id = product2.id

        expect { category.destroy }.to change { Product.count }.by(-2)
        expect(Product.find_by(id: product1_id)).to be_nil
        expect(Product.find_by(id: product2_id)).to be_nil
      end
    end
  end
end

