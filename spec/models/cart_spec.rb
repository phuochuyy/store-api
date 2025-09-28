require 'rails_helper'

RSpec.describe Cart, type: :model do
  describe 'associations' do
    it 'belongs to user optionally' do
      cart = Cart.new
      expect(cart).to respond_to(:user)
    end

    it 'has many cart items' do
      cart = Cart.new
      expect(cart).to respond_to(:cart_items)
    end

    it 'has many products through cart items' do
      cart = Cart.new
      expect(cart).to respond_to(:products)
    end
  end

  describe 'validations' do
    it 'validates presence of session_id' do
      cart = Cart.new
      cart.valid?
      expect(cart.errors[:session_id]).to include("can't be blank")
    end

    it 'validates inclusion of status' do
      expect do
        Cart.new(status: 'invalid')
      end.to raise_error(ArgumentError, "'invalid' is not a valid status")
    end

    it 'validates numericality of total_amount' do
      cart = Cart.new(total_amount: -1)
      cart.valid?
      expect(cart.errors[:total_amount]).to include('must be greater than or equal to 0')
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Cart.statuses).to eq({
                                    'active' => 'active',
                                    'abandoned' => 'abandoned',
                                    'completed' => 'completed'
                                  })
    end
  end

  describe 'scopes' do
    let!(:active_cart) { create(:cart, status: 'active') }
    let!(:abandoned_cart) { create(:cart, status: 'abandoned') }
    let!(:user) { create(:user) }
    let!(:user_cart) { create(:cart, user: user) }

    it 'filters active carts' do
      expect(Cart.active).to include(active_cart)
      expect(Cart.active).not_to include(abandoned_cart)
    end

    it 'filters carts for user' do
      expect(Cart.for_user(user)).to include(user_cart)
    end

    it 'filters carts for session' do
      expect(Cart.for_session(active_cart.session_id)).to include(active_cart)
    end
  end

  describe 'methods' do
    let(:cart) { create(:cart) }
    let(:product) { create(:product, price: 100.0) }

    describe '#total_items' do
      it 'returns total quantity of items' do
        create(:cart_item, cart: cart, quantity: 2)
        create(:cart_item, cart: cart, quantity: 3)

        expect(cart.total_items).to eq(5)
      end
    end

    describe '#calculate_total_amount' do
      it 'calculates and updates total amount' do
        cart_item1 = create(:cart_item, cart: cart, quantity: 2, unit_price: 50.0)
        cart_item2 = create(:cart_item, cart: cart, quantity: 1, unit_price: 100.0)

        # Reset total_amount to test calculation
        cart.update_column(:total_amount, 0.0)

        total = cart.calculate_total_amount
        expect(total.to_f).to eq(200.0)
        expect(cart.reload.total_amount.to_f).to eq(200.0)
      end
    end

    describe '#add_product' do
      it 'adds new product to cart' do
        cart.add_product(product, 2)

        cart_item = cart.cart_items.find_by(product: product)
        expect(cart_item).to be_present
        expect(cart_item.quantity).to eq(2)
        expect(cart_item.unit_price).to eq(product.price)
      end

      it 'increments quantity for existing product' do
        create(:cart_item, cart: cart, product: product, quantity: 1)

        cart.add_product(product, 2)

        cart_item = cart.cart_items.find_by(product: product)
        expect(cart_item.quantity).to eq(3)
      end
    end

    describe '#remove_product' do
      it 'removes product from cart' do
        create(:cart_item, cart: cart, product: product)

        result = cart.remove_product(product)
        expect(result).to be true
        expect(cart.cart_items.find_by(product: product)).to be_nil
      end

      it 'returns false if product not in cart' do
        result = cart.remove_product(product)
        expect(result).to be false
      end
    end

    describe '#update_product_quantity' do
      it 'updates product quantity' do
        create(:cart_item, cart: cart, product: product, quantity: 1)

        result = cart.update_product_quantity(product, 5)
        expect(result).to be true

        cart_item = cart.cart_items.find_by(product: product)
        expect(cart_item.quantity).to eq(5)
      end

      it 'removes product if quantity is 0' do
        create(:cart_item, cart: cart, product: product, quantity: 1)

        result = cart.update_product_quantity(product, 0)
        expect(result).to be true
        expect(cart.cart_items.find_by(product: product)).to be_nil
      end
    end

    describe '#clear' do
      it 'removes all items from cart' do
        cart_items = create_list(:cart_item, 3, cart: cart)

        cart.clear
        cart.reload
        expect(cart.cart_items.count).to eq(0)
        expect(cart.total_amount.to_f).to eq(0.0)
      end
    end

    describe '#empty?' do
      it 'returns true when cart has no items' do
        expect(cart.empty?).to be true
      end

      it 'returns false when cart has items' do
        create(:cart_item, cart: cart)
        expect(cart.empty?).to be false
      end
    end

    describe '.find_or_create_for_user' do
      let(:user) { create(:user) }

      it 'finds existing active cart for user' do
        existing_cart = create(:cart, user: user, status: 'active')

        cart = Cart.find_or_create_for_user(user)
        expect(cart).to eq(existing_cart)
      end

      it 'creates new cart for user' do
        expect do
          Cart.find_or_create_for_user(user)
        end.to change(Cart, :count).by(1)
      end
    end

    describe '.find_or_create_for_session' do
      let(:session_id) { SecureRandom.uuid }

      it 'finds existing active cart for session' do
        existing_cart = create(:cart, session_id: session_id, status: 'active')

        cart = Cart.find_or_create_for_session(session_id)
        expect(cart).to eq(existing_cart)
      end

      it 'creates new cart for session' do
        expect do
          Cart.find_or_create_for_session(session_id)
        end.to change(Cart, :count).by(1)
      end
    end
  end
end
