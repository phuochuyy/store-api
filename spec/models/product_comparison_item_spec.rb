require 'rails_helper'

RSpec.describe ProductComparisonItem, type: :model do
  let(:comparison) { create(:product_comparison) }
  let(:product) { create(:product) }
  let(:item) { create(:product_comparison_item, product_comparison: comparison, product: product) }

  describe 'associations' do
    it { should belong_to(:product_comparison) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it 'validates uniqueness of product within comparison' do
      create(:product_comparison_item, product_comparison: comparison, product: product)
      duplicate = build(:product_comparison_item, product_comparison: comparison, product: product)
      expect(duplicate).not_to be_valid
    end

    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'orders by position and created_at' do
        item1 = create(:product_comparison_item, product_comparison: comparison, position: 1, created_at: 2.days.ago)
        item2 = create(:product_comparison_item, product_comparison: comparison, position: 0, created_at: 1.day.ago)
        expect(ProductComparisonItem.ordered).to eq([item2, item1])
      end
    end
  end
end

