require 'rails_helper'

RSpec.describe Order, type: :model do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user) }
  let(:product) { create(:product) }

  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should belong_to(:discount).optional }
    it { should have_many(:order_items).dependent(:destroy) }
    it { should have_many(:products).through(:order_items) }
    it { should have_many(:payments).dependent(:destroy) }
    it { should have_many(:coupons).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:order) }

    it { should validate_presence_of(:customer_name) }
    it { should validate_presence_of(:customer_email) }
    it { should validate_presence_of(:customer_phone) }
    it { should validate_presence_of(:status) }
    it { should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0).allow_nil }

    it 'validates email format' do
      order = build(:order, customer_email: 'invalid-email')
      expect(order).not_to be_valid
      expect(order.errors[:customer_email]).to be_present
    end

    it 'validates status inclusion' do
      order = build(:order)
      order.status = 'invalid_status'
      expect(order).not_to be_valid
      expect(order.errors[:status]).to be_present
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Order.statuses.keys).to include('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'paid')
    end
  end

  describe 'scopes' do
    let!(:recent_order) { create(:order, created_at: 1.day.ago) }
    let!(:old_order) { create(:order, created_at: 2.days.ago) }

    describe '.recent' do
      it 'orders by created_at desc' do
        orders = Order.recent.limit(2).to_a
        expect(orders.first.created_at).to be > orders.last.created_at
      end
    end
  end

  describe '#update_total_amount' do
    it 'calculates total from order items' do
      item1 = build(:order_item, order: order, product: product, quantity: 2, unit_price: 100.00)
      item2 = build(:order_item, order: order, product: create(:product), quantity: 1, unit_price: 50.00)
      order.order_items << item1
      order.order_items << item2
      order.save!

      # update_total_amount is called by order_item callbacks, but we can test it directly
      order.update_total_amount
      expect(order.reload.total_amount.to_f).to eq(250.00)
    end

    it 'subtracts discount_amount from total' do
      item = build(:order_item, order: order, product: product, quantity: 1, unit_price: 100.00)
      order.order_items << item
      order.update!(discount_amount: 10.00)
      order.update_total_amount
      expect(order.reload.total_amount.to_f).to eq(90.00)
    end
  end

  describe '#subtotal_amount' do
    it 'returns sum of order items total_price' do
      item1 = build(:order_item, order: order, product: product, quantity: 2, unit_price: 100.00)
      item2 = build(:order_item, order: order, product: create(:product), quantity: 1, unit_price: 50.00)
      order.order_items << item1
      order.order_items << item2
      order.save!
      expect(order.subtotal_amount.to_f).to eq(250.00)
    end
  end

  describe '#final_amount' do
    it 'returns subtotal minus discount' do
      item = build(:order_item, order: order, product: product, quantity: 1, unit_price: 100.00)
      order.order_items << item
      order.update!(discount_amount: 10.00)
      expect(order.final_amount.to_f).to eq(90.00)
    end
  end

  describe '#discount?' do
    it 'returns true when discount_amount is present and positive' do
      order.update!(discount_amount: 10.00)
      expect(order.discount?).to be true
    end

    it 'returns false when discount_amount is nil' do
      expect(order.discount?).to be false
    end

    it 'returns false when discount_amount is 0' do
      order.update!(discount_amount: 0)
      expect(order.discount?).to be false
    end
  end

  describe '#apply_discount' do
    let(:discount) { create(:discount, code: 'TEST10', discount_type: 'percentage', value: 10, minimum_amount: 0) }
    let(:order_with_items) do
      o = create(:order, user: user)
      item = build(:order_item, order: o, product: product, quantity: 2, unit_price: 100.00)
      o.order_items << item
      o.save!
      o
    end

    it 'applies discount successfully' do
      result = order_with_items.apply_discount('TEST10')
      expect(result[:success]).to be true
      expect(order_with_items.reload.discount_id).to eq(discount.id)
      expect(order_with_items.discount_code).to eq('TEST10')
    end

    it 'returns error for invalid discount code' do
      result = order_with_items.apply_discount('INVALID')
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Invalid discount code')
    end
  end

  describe '#remove_discount' do
    it 'removes discount from order' do
      discount = create(:discount)
      order.update!(discount: discount, discount_code: discount.code, discount_amount: 10.00)
      result = order.remove_discount
      expect(result[:success]).to be true
      expect(order.reload.discount).to be_nil
      expect(order.discount_code).to be_nil
      expect(order.discount_amount.to_f).to eq(0)
    end
  end

  describe '#total_items' do
    it 'returns sum of order items quantities' do
      item1 = build(:order_item, order: order, product: product, quantity: 2)
      item2 = build(:order_item, order: order, product: create(:product), quantity: 3)
      order.order_items << item1
      order.order_items << item2
      order.save!
      expect(order.total_items).to eq(5)
    end
  end

  describe 'discount validation' do
    it 'validates discount_code matches discount_id' do
      discount = create(:discount, code: 'TEST10')
      order = build(:order, discount_id: discount.id, discount_code: 'WRONG')
      expect(order).not_to be_valid
      expect(order.errors[:discount_code]).to be_present
    end

    it 'passes validation when discount_code matches' do
      discount = create(:discount, code: 'TEST10')
      order = build(:order, discount_id: discount.id, discount_code: 'TEST10')
      expect(order).to be_valid
    end
  end

  describe 'status methods' do
    it 'has status check methods' do
      order.status = 'confirmed'
      order.save!
      expect(order.status).to eq('confirmed')
      expect(order.pending?).to be false
    end
  end
end

