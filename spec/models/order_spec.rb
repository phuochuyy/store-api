require 'rails_helper'

RSpec.describe Order, type: :model do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:phone) { create(:phone, brand: brand, category: category, price: 1000) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      order = build(:order)
      expect(order).to be_valid
    end

    it 'is invalid without customer_name' do
      order = build(:order, customer_name: nil)
      expect(order).not_to be_valid
      expect(order.errors[:customer_name]).to include("can't be blank")
    end

    it 'is invalid without customer_email' do
      order = build(:order, customer_email: nil)
      expect(order).not_to be_valid
      expect(order.errors[:customer_email]).to include("can't be blank")
    end

    it 'is invalid with invalid email format' do
      order = build(:order, customer_email: 'invalid-email')
      expect(order).not_to be_valid
      expect(order.errors[:customer_email]).to include('is invalid')
    end

    it 'is invalid without customer_phone' do
      order = build(:order, customer_phone: nil)
      expect(order).not_to be_valid
      expect(order.errors[:customer_phone]).to include("can't be blank")
    end

    it 'is invalid without status' do
      order = build(:order, status: nil)
      expect(order).not_to be_valid
      expect(order.errors[:status]).to include("can't be blank")
    end

    it 'is invalid with invalid status' do
      expect { build(:order, status: 'invalid_status') }.to raise_error(ArgumentError)
    end

    it 'is valid with pending status' do
      order = build(:order, status: 'pending')
      expect(order).to be_valid
    end

    it 'is valid with confirmed status' do
      order = build(:order, status: 'confirmed')
      expect(order).to be_valid
    end

    it 'is valid with shipped status' do
      order = build(:order, status: 'shipped')
      expect(order).to be_valid
    end

    it 'is valid with delivered status' do
      order = build(:order, status: 'delivered')
      expect(order).to be_valid
    end

    it 'is valid with cancelled status' do
      order = build(:order, status: 'cancelled')
      expect(order).to be_valid
    end
  end

  describe 'associations' do
    let(:order) { create(:order) }

    it 'has many order_items' do
      expect(order).to respond_to(:order_items)
    end

    it 'destroys associated order_items when destroyed' do
      order_item = create(:order_item, order: order, phone: phone)
      expect { order.destroy }.to change(OrderItem, :count).by(-1)
    end
  end

  describe 'scopes' do
    let!(:recent_order) { create(:order, created_at: 1.day.ago) }
    let!(:old_order) { create(:order, created_at: 1.week.ago) }

    it 'orders by created_at desc by default' do
      expect(Order.all.first).to eq(recent_order)
    end

    it 'has recent scope' do
      recent_orders = Order.recent
      expect(recent_orders.first).to eq(recent_order)
    end
  end

  describe 'methods' do
    let(:order) { create(:order) }
    let!(:order_item1) { create(:order_item, order: order, phone: phone, quantity: 2, unit_price: 1000) }
    let!(:order_item2) { create(:order_item, order: order, phone: phone, quantity: 1, unit_price: 500) }

    describe '#update_total_amount' do
      it 'calculates total amount from order items' do
        # Reset total_amount to test the calculation
        order.update_column(:total_amount, 0)
        order.update_total_amount
        # Debug: check actual order items
        total = order.order_items.sum { |item| item.quantity * item.unit_price }
        expect(order.total_amount.to_f).to eq(total.to_f)
      end

      it 'updates the order in database' do
        expect { order.update_total_amount }.to(change { order.reload.total_amount })
      end
    end

    describe '#total_items' do
      it 'returns total quantity of items' do
        expect(order.total_items).to eq(3) # 2 + 1
      end
    end
  end

  describe 'enums' do
    it 'defines status enum correctly' do
      expect(Order.statuses).to eq({
                                     'pending' => 'pending',
                                     'confirmed' => 'confirmed',
                                     'shipped' => 'shipped',
                                     'delivered' => 'delivered',
                                     'cancelled' => 'cancelled'
                                   })
    end
  end

  describe 'callbacks' do
    it 'updates total amount after order items are added' do
      order = create(:order)
      create(:order_item, order: order, phone: phone, quantity: 2, unit_price: 1000)

      expect(order.reload.total_amount).to eq(2000)
    end
  end
end
