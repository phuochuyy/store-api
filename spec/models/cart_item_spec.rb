require 'rails_helper'

RSpec.describe CartItem, type: :model do
  describe 'associations' do
    it 'belongs to cart' do
      cart_item = CartItem.new
      expect(cart_item).to respond_to(:cart)
    end

    it 'belongs to product' do
      cart_item = CartItem.new
      expect(cart_item).to respond_to(:product)
    end
  end

  describe 'validations' do
    it 'validates presence of quantity' do
      cart_item = CartItem.new
      cart_item.valid?
      expect(cart_item.errors[:quantity]).to include("can't be blank")
    end

    it 'validates numericality of quantity' do
      cart_item = CartItem.new(quantity: 0)
      cart_item.valid?
      expect(cart_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'validates presence of unit_price' do
      cart_item = CartItem.new
      cart_item.valid?
      expect(cart_item.errors[:unit_price]).to include("can't be blank")
    end

    it 'validates numericality of unit_price' do
      cart_item = CartItem.new(unit_price: 0)
      cart_item.valid?
      expect(cart_item.errors[:unit_price]).to include('must be greater than 0')
    end

    it 'validates uniqueness of product_id scoped to cart_id' do
      cart = create(:cart)
      product = create(:product)
      create(:cart_item, cart: cart, product: product)

      duplicate_cart_item = build(:cart_item, cart: cart, product: product)
      duplicate_cart_item.valid?
      expect(duplicate_cart_item.errors[:product_id]).to include('has already been taken')
    end
  end

  describe 'callbacks' do
    let(:cart) { create(:cart) }
    let(:product) { create(:product, price: 100.0) }

    it 'sets unit_price from product before validation' do
      cart_item = build(:cart_item, cart: cart, product: product, unit_price: nil)
      cart_item.valid?
      expect(cart_item.unit_price).to eq(product.price)
    end

    it 'updates cart total after create' do
      expect(cart).to receive(:calculate_total_amount)
      create(:cart_item, cart: cart, product: product)
    end

    it 'updates cart total after update' do
      cart_item = create(:cart_item, cart: cart, product: product)
      expect(cart).to receive(:calculate_total_amount)
      cart_item.update!(quantity: 2)
    end

    it 'updates cart total after destroy' do
      cart_item = create(:cart_item, cart: cart, product: product)
      expect(cart).to receive(:calculate_total_amount)
      cart_item.destroy
    end
  end

  describe 'methods' do
    let(:cart_item) { create(:cart_item, quantity: 2, unit_price: 50.0) }

    describe '#total_price' do
      it 'calculates total price' do
        expect(cart_item.total_price).to eq(100.0)
      end
    end

    describe '#increment_quantity' do
      it 'increments quantity by specified amount' do
        cart_item.increment_quantity(3)
        expect(cart_item.quantity).to eq(5)
      end

      it 'increments quantity by 1 by default' do
        cart_item.increment_quantity
        expect(cart_item.quantity).to eq(3)
      end
    end

    describe '#decrement_quantity' do
      it 'decrements quantity by specified amount' do
        cart_item.decrement_quantity(1)
        expect(cart_item.quantity).to eq(1)
      end

      it 'destroys item when quantity reaches 0' do
        expect do
          cart_item.decrement_quantity(2)
        end.to change(CartItem, :count).by(-1)
      end

      it 'destroys item when quantity goes below 0' do
        expect do
          cart_item.decrement_quantity(3)
        end.to change(CartItem, :count).by(-1)
      end
    end
  end
end
