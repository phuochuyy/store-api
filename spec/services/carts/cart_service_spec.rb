require 'rails_helper'

RSpec.describe Carts::CartService, type: :service do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 100.0, stock_quantity: 10) }
  let(:cart) { create(:cart, user: user) }

  describe '.get_or_create_cart' do
    context 'with user' do
      it 'returns existing cart for user' do
        existing_cart = create(:cart, user: user, status: 'active')

        result = described_class.get_or_create_cart(user: user)

        expect(result[:success]).to be true
        expect(result[:cart]).to eq(existing_cart)
      end

      it 'creates new cart for user' do
        expect do
          described_class.get_or_create_cart(user: user)
        end.to change(Cart, :count).by(1)
      end
    end

    context 'with session_id' do
      let(:session_id) { SecureRandom.uuid }

      it 'returns existing cart for session' do
        existing_cart = create(:cart, session_id: session_id, status: 'active')

        result = described_class.get_or_create_cart(session_id: session_id)

        expect(result[:success]).to be true
        expect(result[:cart]).to eq(existing_cart)
      end
    end

    context 'without user or session_id' do
      it 'raises ArgumentError' do
        expect do
          described_class.get_or_create_cart
        end.to raise_error(ArgumentError, 'Either user or session_id must be provided')
      end
    end
  end

  describe '.add_to_cart' do
    it 'adds product to cart successfully' do
      result = described_class.add_to_cart(cart, product.id, 2)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Product added to cart successfully')

      cart_item = cart.cart_items.find_by(product: product)
      expect(cart_item.quantity).to eq(2)
    end

    it 'returns error for out of stock product' do
      out_of_stock_product = create(:product, stock_quantity: 0)

      result = described_class.add_to_cart(cart, out_of_stock_product.id, 1)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Product is out of stock')
    end

    it 'returns error for insufficient stock' do
      result = described_class.add_to_cart(cart, product.id, 15)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Only 10 items available in stock')
    end

    it 'returns error for non-existent product' do
      result = described_class.add_to_cart(cart, 999, 1)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Product not found')
    end
  end

  describe '.remove_from_cart' do
    let!(:cart_item) { create(:cart_item, cart: cart, product: product) }

    it 'removes product from cart successfully' do
      result = described_class.remove_from_cart(cart, product.id)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Product removed from cart successfully')
      expect(cart.cart_items.find_by(product: product)).to be_nil
    end

    it 'returns error if product not in cart' do
      other_product = create(:product)

      result = described_class.remove_from_cart(cart, other_product.id)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Product not found in cart')
    end
  end

  describe '.update_cart_item_quantity' do
    let!(:cart_item) { create(:cart_item, cart: cart, product: product, quantity: 2) }

    it 'updates quantity successfully' do
      result = described_class.update_cart_item_quantity(cart, product.id, 5)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Cart updated successfully')
      expect(cart_item.reload.quantity).to eq(5)
    end

    it 'removes item when quantity is 0' do
      result = described_class.update_cart_item_quantity(cart, product.id, 0)

      expect(result[:success]).to be true
      expect(cart.cart_items.find_by(product: product)).to be_nil
    end

    it 'returns error for insufficient stock' do
      result = described_class.update_cart_item_quantity(cart, product.id, 15)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Only 10 items available in stock')
    end
  end

  describe '.clear_cart' do
    let!(:cart_items) { create_list(:cart_item, 3, cart: cart) }

    it 'clears all items from cart' do
      result = described_class.clear_cart(cart)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Cart cleared successfully')
      expect(cart.cart_items.count).to eq(0)
      expect(cart.total_amount).to eq(0.0)
    end
  end

  describe '.get_cart_details' do
    let!(:cart_items) { create_list(:cart_item, 2, cart: cart) }

    it 'returns cart details' do
      result = described_class.get_cart_details(cart)

      expect(result[:success]).to be true
      expect(result[:cart]).to eq(cart)
      expect(result[:cart_items]).to eq(cart.cart_items)
      expect(result[:total_items]).to eq(cart.total_items)
      expect(result[:total_amount]).to eq(cart.total_amount)
    end
  end

  describe '.merge_carts' do
    let(:guest_cart) { create(:cart, :guest_cart) }
    let(:user_cart) { create(:cart, user: user) }
    let!(:guest_cart_item) { create(:cart_item, cart: guest_cart, product: product, quantity: 2) }

    it 'merges guest cart with user cart' do
      result = described_class.merge_carts(guest_cart, user_cart)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Carts merged successfully')
      expect(guest_cart.reload.status).to eq('abandoned')

      user_cart_item = user_cart.cart_items.find_by(product: product)
      expect(user_cart_item.quantity).to eq(2)
    end

    it 'merges quantities for existing products' do
      create(:cart_item, cart: user_cart, product: product, quantity: 1)

      result = described_class.merge_carts(guest_cart, user_cart)

      expect(result[:success]).to be true

      user_cart_item = user_cart.cart_items.find_by(product: product)
      expect(user_cart_item.quantity).to eq(3)
    end
  end

  describe '.validate_cart_for_checkout' do
    it 'returns success for valid cart' do
      create(:cart_item, cart: cart, product: product, quantity: 2)

      result = described_class.validate_cart_for_checkout(cart)

      expect(result[:success]).to be true
    end

    it 'returns error for empty cart' do
      result = described_class.validate_cart_for_checkout(cart)

      expect(result[:success]).to be false
      expect(result[:errors]).to include('Cart is empty')
    end

    it 'returns error for out of stock products' do
      out_of_stock_product = create(:product, stock_quantity: 0)
      create(:cart_item, cart: cart, product: out_of_stock_product, quantity: 1)

      result = described_class.validate_cart_for_checkout(cart)

      expect(result[:success]).to be false
      expect(result[:errors]).to include("#{out_of_stock_product.name} is out of stock")
    end
  end
end
