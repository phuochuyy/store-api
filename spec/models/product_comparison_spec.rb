require 'rails_helper'

RSpec.describe ProductComparison, type: :model do
  let(:user) { create(:user) }
  let(:product1) { create(:product) }
  let(:product2) { create(:product) }
  let(:comparison) { create(:product_comparison, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:product_comparison_items).dependent(:destroy) }
    it { should have_many(:products).through(:product_comparison_items) }
  end

  describe 'validations' do
    it 'validates product_ids presence when no items' do
      comparison = build(:product_comparison, user: user, product_ids: nil)
      expect(comparison).not_to be_valid
    end

    it 'allows empty product_ids when items exist' do
      comparison = create(:product_comparison, user: user)
      create(:product_comparison_item, product_comparison: comparison, product: product1)
      comparison.product_ids = nil
      expect(comparison).to be_valid
    end
  end

  describe '#product_ids_array' do
    it 'returns product_ids from junction table' do
      create(:product_comparison_item, product_comparison: comparison, product: product1, position: 0)
      create(:product_comparison_item, product_comparison: comparison, product: product2, position: 1)
      expect(comparison.product_ids_array).to eq([product1.id, product2.id])
    end

    it 'returns empty array when no items' do
      expect(comparison.product_ids_array).to eq([])
    end
  end

  describe '#add_product' do
    it 'adds product to comparison' do
      expect { comparison.add_product(product1) }.to change { comparison.products.count }.by(1)
      expect(comparison.products).to include(product1)
    end

    it 'does not add duplicate product' do
      comparison.add_product(product1)
      expect(comparison.add_product(product1)).to be false
      expect(comparison.products.count).to eq(1)
    end

    it 'sets position automatically' do
      comparison.add_product(product1)
      comparison.add_product(product2)
      items = comparison.product_comparison_items.order(:position)
      expect(items.first.position).to eq(0)
      expect(items.second.position).to eq(1)
    end
  end

  describe '#remove_product' do
    it 'removes product from comparison' do
      comparison.add_product(product1)
      comparison.remove_product(product1)
      expect(comparison.products).not_to include(product1)
    end
  end

  describe '#products_ordered' do
    it 'returns products in position order' do
      comparison.add_product(product2)
      comparison.add_product(product1)
      expect(comparison.products_ordered.first).to eq(product2)
      expect(comparison.products_ordered.second).to eq(product1)
    end
  end
end

