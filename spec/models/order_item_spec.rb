require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe OrderItem, type: :model do
  let(:order) { create(:order) }
  let(:product) { create(:product, price: 100.00) }
  let(:order_item) { create(:order_item, order: order, product: product) }

  describe 'associations' do
    it { should belong_to(:order) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    subject { build(:order_item, order: order, product: product) }

    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }

    it { should validate_presence_of(:unit_price) }
    it { should validate_numericality_of(:unit_price).is_greater_than_or_equal_to(0) }
  end

  describe 'callbacks' do
    describe 'before_validation :set_unit_price_from_product' do
      it 'sets unit_price from product price if not provided' do
        item = build(:order_item, order: order, product: product, unit_price: nil)
        item.valid?
        expect(item.unit_price).to eq(product.price)
      end

      it 'does not override provided unit_price' do
        item = build(:order_item, order: order, product: product, unit_price: 50.00)
        item.valid?
        expect(item.unit_price).to eq(50.00)
      end
    end

    describe 'after_create :update_order_total' do
      it 'updates order total_amount after creation' do
        allow(order).to receive(:update_total_amount)
        create(:order_item, order: order, product: product, quantity: 2, unit_price: 100.00)
        expect(order).to have_received(:update_total_amount)
      end
    end

    describe 'after_update :update_order_total' do
      it 'updates order total_amount after update' do
        allow(order).to receive(:update_total_amount)
        order_item.update!(quantity: 5)
        expect(order).to have_received(:update_total_amount)
      end
    end

    describe 'after_destroy :update_order_total' do
      it 'updates order total_amount after destroy' do
        allow(order).to receive(:update_total_amount)
        order_item.destroy
        expect(order).to have_received(:update_total_amount)
      end
    end
  end

  describe '#total_price' do
    it 'calculates total price correctly' do
      item = create(:order_item, order: order, product: product, quantity: 3, unit_price: 100.00)
      expect(item.total_price).to eq(300.00)
    end
  end
end
# rubocop:enable Metrics/BlockLength
