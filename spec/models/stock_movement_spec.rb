require 'rails_helper'

RSpec.describe StockMovement, type: :model do
  let(:product) { create(:product) }
  let(:user) { create(:user) }
  let(:movement) { create(:stock_movement, product: product, user: user) }

  describe 'associations' do
    it { should belong_to(:product) }
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:movement_type) }
    it { should validate_presence_of(:quantity) }
    it { should validate_presence_of(:previous_quantity) }
    it { should validate_presence_of(:new_quantity) }
    it { should validate_numericality_of(:quantity).other_than(0) }
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at desc' do
        old_movement = create(:stock_movement, product: product, created_at: 2.days.ago)
        new_movement = create(:stock_movement, product: product, created_at: 1.day.ago)
        expect(StockMovement.recent.first).to eq(new_movement)
      end
    end

    describe '.by_movement_type' do
      it 'filters by movement type' do
        order_movement = create(:stock_movement, product: product, movement_type: 'order_created')
        expect(StockMovement.by_movement_type('order_created')).to include(order_movement)
      end
    end
  end

  describe '.get_movements_for_product' do
    it 'returns movements for product' do
      create(:stock_movement, product: product)
      other_product = create(:product)
      create(:stock_movement, product: other_product)
      expect(StockMovement.get_movements_for_product(product).count).to eq(1)
    end

    it 'filters by movement_type when provided' do
      create(:stock_movement, product: product, movement_type: 'order_created')
      create(:stock_movement, product: product, movement_type: 'order_cancelled')
      movements = StockMovement.get_movements_for_product(product, movement_type: 'order_created')
      expect(movements.count).to eq(1)
    end
  end
end

