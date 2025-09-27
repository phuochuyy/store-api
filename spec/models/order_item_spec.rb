require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:phone) { create(:phone, brand: brand, category: category, price: 1000) }
  let(:order) { create(:order) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      order_item = build(:order_item, order: order, phone: phone)
      expect(order_item).to be_valid
    end

    it 'is invalid without an order' do
      order_item = build(:order_item, order: nil, phone: phone)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:order]).to include('must exist')
    end

    it 'is invalid without a phone' do
      order_item = build(:order_item, order: order, phone: nil)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:phone]).to include('must exist')
    end

    it 'is invalid without quantity' do
      order_item = build(:order_item, order: order, phone: phone, quantity: nil)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:quantity]).to include("can't be blank")
    end

    it 'is invalid with zero quantity' do
      order_item = build(:order_item, order: order, phone: phone, quantity: 0)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'is invalid with negative quantity' do
      order_item = build(:order_item, order: order, phone: phone, quantity: -1)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'is valid with positive quantity' do
      order_item = build(:order_item, order: order, phone: phone, quantity: 5)
      expect(order_item).to be_valid
    end

    it 'is invalid without unit_price' do
      order_item = build(:order_item, order: order, phone: nil, unit_price: nil)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:unit_price]).to include("can't be blank")
    end

    it 'is invalid with negative unit_price' do
      order_item = build(:order_item, order: order, phone: phone, unit_price: -100)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:unit_price]).to include('must be greater than or equal to 0')
    end

    it 'is valid with zero unit_price' do
      order_item = build(:order_item, order: order, phone: phone, unit_price: 0)
      expect(order_item).to be_valid
    end

    it 'is valid with positive unit_price' do
      order_item = build(:order_item, order: order, phone: phone, unit_price: 1000)
      expect(order_item).to be_valid
    end
  end

  describe 'associations' do
    let(:order_item) { create(:order_item, order: order, phone: phone) }

    it 'belongs to an order' do
      expect(order_item).to respond_to(:order)
      expect(order_item.order).to eq(order)
    end

    it 'belongs to a phone' do
      expect(order_item).to respond_to(:phone)
      expect(order_item.phone).to eq(phone)
    end
  end

  describe 'methods' do
    let(:order_item) { create(:order_item, order: order, phone: phone, quantity: 3, unit_price: 1000) }

    describe '#total_price' do
      it 'calculates total price correctly' do
        expect(order_item.total_price).to eq(3000) # 3 * 1000
      end
    end
  end

  describe 'callbacks' do
    it 'sets unit_price from phone price before validation' do
      order_item = build(:order_item, order: order, phone: phone, unit_price: nil)
      order_item.valid?
      expect(order_item.unit_price).to eq(phone.price)
    end

    it 'updates order total amount after creation' do
      expect do
        create(:order_item, order: order, phone: phone, quantity: 2, unit_price: 1000)
      end.to(change { order.reload.total_amount })
    end

    it 'updates order total amount after update' do
      order_item = create(:order_item, order: order, phone: phone, quantity: 2, unit_price: 1000)
      expect do
        order_item.update(quantity: 3)
      end.to(change { order.reload.total_amount })
    end

    it 'updates order total amount after destruction' do
      order_item = create(:order_item, order: order, phone: phone, quantity: 2, unit_price: 1000)
      expect do
        order_item.destroy
      end.to(change { order.reload.total_amount })
    end
  end
end
