# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::ShippingService do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:product) { create(:product, stock_quantity: 10) }
  let(:order) { create(:order, :confirmed, user: customer_user) }
  let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2) }

  describe '.ship_order' do
    context 'when order can be shipped' do
      it 'ships the order successfully' do
        result = described_class.ship_order(
          order,
          admin_user,
          tracking_number: 'TRK123456',
          carrier: 'DHL'
        )

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Order shipped successfully')

        order.reload
        expect(order.status).to eq('shipped')
        expect(order.tracking_number).to eq('TRK123456')
        expect(order.carrier).to eq('DHL')
        expect(order.shipped_at).to be_present
      end

      it 'ships the order without tracking info' do
        result = described_class.ship_order(order, admin_user)

        expect(result[:success]).to be true

        order.reload
        expect(order.status).to eq('shipped')
        expect(order.tracking_number).to be_nil
        expect(order.carrier).to be_nil
        expect(order.shipped_at).to be_present
      end

      it 'creates notifications for customer and admins' do
        # Create another admin user to receive admin notification
        create(:user, role: 'admin')

        expect do
          described_class.ship_order(order, admin_user, tracking_number: 'TRK123')
        end.to change(Notification, :count).by(2)

        customer_notification = Notification.find_by(user: customer_user, notification_type: 'order_shipped')
        expect(customer_notification).to be_present
        expect(customer_notification.message).to include('has been shipped')
        expect(customer_notification.metadata['tracking_number']).to eq('TRK123')

        admin_notification = Notification.find_by(notification_type: 'order_shipped_admin')
        expect(admin_notification).to be_present
      end
    end

    context 'when order cannot be shipped' do
      it 'returns error for pending order' do
        order.update!(status: 'pending')

        result = described_class.ship_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be shipped')
        expect(result[:details]).to include('Only confirmed orders can be shipped')
      end

      it 'returns error for already shipped order' do
        order.update!(status: 'shipped')

        result = described_class.ship_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be shipped')
      end

      it 'returns error for order without items' do
        order.order_items.destroy_all

        result = described_class.ship_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be shipped')
        expect(result[:details]).to eq('Order has no items')
      end

      it 'returns error when order is nil' do
        result = described_class.ship_order(nil, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order not found')
      end

      it 'returns error when user is nil' do
        result = described_class.ship_order(order, nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end

    context 'when an error occurs' do
      before do
        allow(order).to receive(:update!).and_raise(StandardError.new('Database error'))
      end

      it 'handles errors gracefully' do
        result = described_class.ship_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to ship order')
        expect(result[:details]).to eq('Database error')
      end
    end
  end
end
