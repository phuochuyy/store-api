require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Cart, type: :model do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:cart) { create(:cart, user: user) }

  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should have_many(:cart_items).dependent(:destroy) }
    it { should have_many(:products).through(:cart_items) }
  end

  describe 'validations' do
    subject { build(:cart) }

    it { should validate_presence_of(:session_id) }
    it { should validate_presence_of(:status) }
    it 'validates status inclusion' do
      cart = build(:cart, status: 'invalid')
      expect(cart).not_to be_valid
      expect(cart.errors[:status]).to be_present
    end
    it { should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Cart.statuses).to eq({ 'active' => 'active', 'abandoned' => 'abandoned', 'completed' => 'completed' })
    end

    it 'defaults to active status' do
      cart = Cart.new(session_id: 'test')
      expect(cart.status).to eq('active')
    end
  end

  describe 'scopes' do
    let!(:active_cart) { create(:cart, status: 'active') }
    let!(:abandoned_cart) { create(:cart, status: 'abandoned') }
    let!(:completed_cart) { create(:cart, status: 'completed') }

    describe '.active' do
      it 'returns only active carts' do
        expect(Cart.active).to include(active_cart)
        expect(Cart.active).not_to include(abandoned_cart, completed_cart)
      end
    end

    describe '.for_user' do
      it 'returns carts for specific user' do
        user_cart = create(:cart, user: user)
        expect(Cart.for_user(user)).to include(user_cart)
      end
    end

    describe '.for_session' do
      it 'returns carts for specific session' do
        session_cart = create(:cart, session_id: 'test_session')
        expect(Cart.for_session('test_session')).to include(session_cart)
      end
    end
  end

  describe '#total_items' do
    it 'returns sum of all cart items quantities' do
      create(:cart_item, cart: cart, product: product, quantity: 2)
      create(:cart_item, cart: cart, product: create(:product), quantity: 3)
      expect(cart.total_items).to eq(5)
    end

    it 'returns 0 when cart is empty' do
      expect(cart.total_items).to eq(0)
    end
  end

  describe '#calculate_total_amount' do
    it 'calculates total from cart items' do
      product1 = create(:product, price: 100.00)
      product2 = create(:product, price: 50.00)
      create(:cart_item, cart: cart, product: product1, quantity: 2, unit_price: 100.00)
      create(:cart_item, cart: cart, product: product2, quantity: 1, unit_price: 50.00)

      total = cart.calculate_total_amount
      expect(total.to_f).to eq(250.00)
      expect(cart.reload.total_amount.to_f).to eq(250.00)
    end
  end

  describe '#add_product' do
    it 'adds new product to cart' do
      expect { cart.add_product(product, 2) }.to change { cart.cart_items.count }.by(1)
      cart_item = cart.cart_items.find_by(product: product)
      expect(cart_item.quantity).to eq(2)
      expect(cart_item.unit_price).to eq(product.price)
    end

    it 'increments quantity if product already in cart' do
      create(:cart_item, cart: cart, product: product, quantity: 1)
      cart.add_product(product, 2)
      cart_item = cart.cart_items.find_by(product: product)
      expect(cart_item.quantity).to eq(3)
    end

    it 'updates total_amount after adding product' do
      cart.add_product(product, 1)
      expect(cart.reload.total_amount).to eq(product.price)
    end
  end

  describe '#remove_product?' do
    it 'removes product from cart' do
      create(:cart_item, cart: cart, product: product)
      expect(cart.remove_product?(product)).to be true
      expect(cart.cart_items.find_by(product: product)).to be_nil
    end

    it 'returns false if product not in cart' do
      expect(cart.remove_product?(product)).to be false
    end

    it 'updates total_amount after removing product' do
      create(:cart_item, cart: cart, product: product, quantity: 1, unit_price: 100.00)
      cart.remove_product?(product)
      expect(cart.reload.total_amount.to_f).to eq(0.0)
    end
  end

  describe '#update_product_quantity?' do
    it 'updates product quantity' do
      create(:cart_item, cart: cart, product: product, quantity: 1)
      cart.update_product_quantity?(product, 5)
      expect(cart.cart_items.find_by(product: product).quantity).to eq(5)
    end

    it 'removes product if quantity is 0' do
      create(:cart_item, cart: cart, product: product, quantity: 1)
      cart.update_product_quantity?(product, 0)
      expect(cart.cart_items.find_by(product: product)).to be_nil
    end

    it 'returns false if product not in cart' do
      expect(cart.update_product_quantity?(product, 5)).to be false
    end
  end

  describe '#clear' do
    it 'removes all cart items' do
      create(:cart_item, cart: cart, product: product)
      create(:cart_item, cart: cart, product: create(:product))
      cart.clear
      expect(cart.cart_items.reload.count).to eq(0)
      expect(cart.reload.total_amount.to_f).to eq(0.0)
    end
  end

  describe '#empty?' do
    it 'returns true when cart has no items' do
      expect(cart.empty?).to be true
    end

    it 'returns false when cart has items' do
      create(:cart_item, cart: cart, product: product)
      expect(cart.empty?).to be false
    end
  end

  describe '.find_or_create_for_user' do
    it 'finds existing active cart for user' do
      existing_cart = create(:cart, user: user, status: 'active')
      found_cart = Cart.find_or_create_for_user(user)
      expect(found_cart).to eq(existing_cart)
    end

    it 'creates new cart if none exists' do
      expect { Cart.find_or_create_for_user(user) }.to change { Cart.count }.by(1)
    end

    it 'creates cart with session_id' do
      cart = Cart.find_or_create_for_user(user)
      expect(cart.session_id).to be_present
    end
  end

  describe '.find_or_create_for_session' do
    it 'finds existing active cart for session' do
      existing_cart = create(:cart, session_id: 'test_session', status: 'active')
      found_cart = Cart.find_or_create_for_session('test_session')
      expect(found_cart).to eq(existing_cart)
    end

    it 'creates new cart if none exists' do
      expect { Cart.find_or_create_for_session('new_session') }.to change { Cart.count }.by(1)
    end
  end
end
# rubocop:enable Metrics/BlockLength
