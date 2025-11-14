require 'rails_helper'

RSpec.describe CartItem, type: :model do
  let(:cart) { create(:cart) }
  let(:product) { create(:product, price: 100.00) }
  let(:cart_item) { create(:cart_item, cart: cart, product: product) }

  describe 'associations' do
    it { should belong_to(:cart) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    subject { build(:cart_item, cart: cart, product: product) }

    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }

    it { should validate_presence_of(:unit_price) }
    it { should validate_numericality_of(:unit_price).is_greater_than(0) }

    it { should validate_uniqueness_of(:product_id).scoped_to(:cart_id) }
  end

  describe 'callbacks' do
    describe 'before_validation :set_unit_price_from_product' do
      it 'sets unit_price from product price if not provided' do
        item = build(:cart_item, cart: cart, product: product, unit_price: nil)
        item.valid?
        expect(item.unit_price).to eq(product.price)
      end

      it 'does not override provided unit_price' do
        item = build(:cart_item, cart: cart, product: product, unit_price: 50.00)
        item.valid?
        expect(item.unit_price).to eq(50.00)
      end
    end

    describe 'after_create :update_cart_total' do
      it 'updates cart total_amount after creation' do
        allow(cart).to receive(:calculate_total_amount)
        create(:cart_item, cart: cart, product: product, quantity: 2, unit_price: 100.00)
        expect(cart).to have_received(:calculate_total_amount)
      end
    end

    describe 'after_update :update_cart_total' do
      it 'updates cart total_amount after update' do
        allow(cart).to receive(:calculate_total_amount)
        cart_item.update!(quantity: 5)
        expect(cart).to have_received(:calculate_total_amount)
      end
    end

    describe 'after_destroy :update_cart_total' do
      it 'updates cart total_amount after destroy' do
        allow(cart).to receive(:calculate_total_amount)
        cart_item.destroy
        expect(cart).to have_received(:calculate_total_amount)
      end
    end
  end

  describe '#total_price' do
    it 'calculates total price correctly' do
      item = create(:cart_item, cart: cart, product: product, quantity: 3, unit_price: 100.00)
      expect(item.total_price).to eq(300.00)
    end
  end

  describe '#increment_quantity' do
    it 'increments quantity by specified amount' do
      cart_item.update!(quantity: 2)
      cart_item.increment_quantity(3)
      expect(cart_item.reload.quantity).to eq(5)
    end

    it 'defaults to increment by 1' do
      cart_item.update!(quantity: 2)
      cart_item.increment_quantity
      expect(cart_item.reload.quantity).to eq(3)
    end
  end

  describe '#decrement_quantity' do
    it 'decrements quantity by specified amount' do
      cart_item.update!(quantity: 5)
      cart_item.decrement_quantity(2)
      expect(cart_item.reload.quantity).to eq(3)
    end

    it 'destroys item if quantity becomes 0 or less' do
      cart_item.update!(quantity: 1)
      expect { cart_item.decrement_quantity(1) }.to change { CartItem.count }.by(-1)
    end

    it 'defaults to decrement by 1' do
      cart_item.update!(quantity: 2)
      cart_item.decrement_quantity
      expect(cart_item.reload.quantity).to eq(1)
    end
  end
end

