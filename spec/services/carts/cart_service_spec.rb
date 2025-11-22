# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Carts::CartService, type: :service do
  let(:user) { create(:user) }
  let(:product) { create(:product, stock_quantity: 10, price: 99.99) }
  let(:session_id) { SecureRandom.uuid }

  describe '.get_or_create_cart' do
    context 'with user' do
      it 'returns existing cart for user' do
        existing_cart = Cart.find_or_create_for_user(user)

        result = described_class.get_or_create_cart(user: user)

        expect(result[:success]).to be true
        expect(result[:cart].id).to eq(existing_cart.id)
        expect(result[:cart_items]).to be_a(ActiveRecord::AssociationRelation)
      end

      it 'creates new cart for user if none exists' do
        result = described_class.get_or_create_cart(user: user)

        expect(result[:success]).to be true
        expect(result[:cart]).to be_persisted
        expect(result[:cart].user).to eq(user)
        expect(result[:cart].status).to eq('active')
      end
    end

    context 'with session_id' do
      it 'returns existing cart for session' do
        existing_cart = create(:cart, session_id: session_id, status: 'active')

        result = described_class.get_or_create_cart(session_id: session_id)

        expect(result[:success]).to be true
        expect(result[:cart].id).to eq(existing_cart.id)
      end

      it 'creates new cart for session if none exists' do
        result = described_class.get_or_create_cart(session_id: session_id)

        expect(result[:success]).to be true
        expect(result[:cart]).to be_persisted
        expect(result[:cart].session_id).to eq(session_id)
        expect(result[:cart].status).to eq('active')
      end
    end

    context 'without user or session_id' do
      it 'raises ArgumentError' do
        expect do
          described_class.get_or_create_cart(user: nil, session_id: nil)
        end.to raise_error(ArgumentError, 'Either user or session_id must be provided')
      end
    end
  end

  describe '.add_to_cart' do
    let(:cart) { create(:cart, user: user) }

    context 'with valid product and quantity' do
      it 'adds product to cart successfully' do
        result = described_class.add_to_cart(cart, product.id, 2)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Product added to cart successfully')
        expect(cart.cart_items.count).to eq(1)
        expect(cart.cart_items.first.quantity).to eq(2)
        expect(cart.cart_items.first.product).to eq(product)
      end

      it 'updates quantity if product already in cart' do
        cart.add_product(product, 1)

        result = described_class.add_to_cart(cart, product.id, 2)

        expect(result[:success]).to be true
        expect(cart.reload.cart_items.count).to eq(1)
        expect(cart.cart_items.first.quantity).to eq(3)
      end

      it 'defaults quantity to 1 if not specified' do
        result = described_class.add_to_cart(cart, product.id)

        expect(result[:success]).to be true
        expect(cart.cart_items.first.quantity).to eq(1)
      end
    end

    context 'with out of stock product' do
      let(:out_of_stock_product) { create(:product, stock_quantity: 0) }

      it 'returns error' do
        result = described_class.add_to_cart(cart, out_of_stock_product.id, 1)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product is out of stock')
        expect(cart.cart_items.count).to eq(0)
      end
    end

    context 'with quantity exceeding stock' do
      it 'returns error' do
        result = described_class.add_to_cart(cart, product.id, 15)

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Only #{product.stock_quantity} items available in stock")
        expect(cart.cart_items.count).to eq(0)
      end
    end

    context 'with non-existent product' do
      it 'returns error' do
        result = described_class.add_to_cart(cart, 999_999, 1)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product not found')
      end
    end
  end

  describe '.remove_from_cart' do
    let(:cart) { create(:cart, user: user) }

    context 'with product in cart' do
      before do
        cart.add_product(product, 2)
      end

      it 'removes product from cart successfully' do
        result = described_class.remove_from_cart(cart, product.id)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Product removed from cart successfully')
        expect(cart.reload.cart_items.count).to eq(0)
      end
    end

    context 'with product not in cart' do
      it 'returns error' do
        result = described_class.remove_from_cart(cart, product.id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product not found in cart')
      end
    end

    context 'with non-existent product' do
      it 'returns error' do
        result = described_class.remove_from_cart(cart, 999_999)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product not found')
      end
    end
  end

  describe '.update_cart_item_quantity' do
    let(:cart) { create(:cart, user: user) }

    context 'with valid quantity' do
      before do
        cart.add_product(product, 1)
      end

      it 'updates quantity successfully' do
        result = described_class.update_cart_item_quantity(cart, product.id, 5)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Cart updated successfully')
        expect(cart.cart_items.first.quantity).to eq(5)
      end
    end

    context 'with out of stock product' do
      let(:out_of_stock_product) { create(:product, stock_quantity: 0) }

      before do
        cart.add_product(out_of_stock_product, 1)
      end

      it 'returns error' do
        result = described_class.update_cart_item_quantity(cart, out_of_stock_product.id, 1)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product is out of stock')
      end
    end

    context 'with quantity exceeding stock' do
      before do
        cart.add_product(product, 1)
      end

      it 'returns error' do
        result = described_class.update_cart_item_quantity(cart, product.id, 15)

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Only #{product.stock_quantity} items available in stock")
      end
    end

    context 'with product not in cart' do
      it 'returns error' do
        result = described_class.update_cart_item_quantity(cart, product.id, 5)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product not found in cart')
      end
    end

    context 'with non-existent product' do
      it 'returns error' do
        result = described_class.update_cart_item_quantity(cart, 999_999, 1)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Product not found')
      end
    end
  end

  describe '.clear_cart' do
    let(:cart) { create(:cart, user: user) }
    let(:product2) { create(:product, stock_quantity: 5, price: 49.99) }

    before do
      cart.add_product(product, 2)
      cart.add_product(product2, 1)
    end

    it 'clears all items from cart' do
      expect(cart.cart_items.count).to eq(2)

      result = described_class.clear_cart(cart)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Cart cleared successfully')
      expect(result[:cart_items]).to eq([])
      expect(cart.reload.cart_items.count).to eq(0)
      expect(cart.total_amount).to eq(0.0)
    end
  end

  describe '.get_cart_details' do
    let(:cart) { create(:cart, user: user) }

    before do
      cart.add_product(product, 2)
      create(:cart_item, cart: cart, product: create(:product, price: 49.99), quantity: 1)
    end

    it 'returns cart details with items and totals' do
      result = described_class.get_cart_details(cart)

      expect(result[:success]).to be true
      expect(result[:cart]).to eq(cart)
      expect(result[:cart_items].count).to eq(2)
      expect(result[:total_items]).to eq(3)
      expect(result[:total_amount]).to be > 0
    end
  end

  describe '.merge_carts' do
    let(:user_cart) { create(:cart, user: user) }
    let(:guest_cart) { create(:cart, session_id: session_id) }
    let(:product2) { create(:product, stock_quantity: 10, price: 49.99) }

    context 'with items in both carts' do
      before do
        guest_cart.add_product(product, 2)
        guest_cart.add_product(product2, 1)
        user_cart.add_product(product, 1)
      end

      it 'merges carts successfully' do
        result = described_class.merge_carts(guest_cart, user_cart)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Carts merged successfully')
        expect(user_cart.reload.cart_items.count).to eq(2)
        expect(user_cart.cart_items.find_by(product: product).quantity).to eq(3)
        expect(user_cart.cart_items.find_by(product: product2).quantity).to eq(1)
      end

      it 'marks guest cart as abandoned' do
        described_class.merge_carts(guest_cart, user_cart)

        expect(guest_cart.reload.status).to eq('abandoned')
      end
    end

    context 'with empty guest cart' do
      it 'returns user cart without changes' do
        user_cart.add_product(product, 1)

        result = described_class.merge_carts(guest_cart, user_cart)

        expect(result[:success]).to be true
        expect(user_cart.reload.cart_items.count).to eq(1)
      end
    end
  end

  describe '.validate_cart_for_checkout' do
    let(:cart) { create(:cart, user: user) }

    context 'with valid cart' do
      before do
        cart.add_product(product, 2)
      end

      it 'returns success' do
        result = described_class.validate_cart_for_checkout(cart)

        expect(result[:success]).to be true
        expect(result[:errors]).to be_nil
      end
    end

    context 'with empty cart' do
      it 'returns error' do
        result = described_class.validate_cart_for_checkout(cart)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Cart is empty')
      end
    end

    context 'with out of stock product' do
      let(:out_of_stock_product) { create(:product, stock_quantity: 0) }

      before do
        cart.add_product(out_of_stock_product, 1)
      end

      it 'returns error' do
        result = described_class.validate_cart_for_checkout(cart)

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/is out of stock/))
      end
    end

    context 'with quantity exceeding stock' do
      before do
        cart.add_product(product, 15)
      end

      it 'returns error' do
        result = described_class.validate_cart_for_checkout(cart)

        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/Only \d+ .* available in stock/))
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
