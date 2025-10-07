# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::DeliveryService do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:product) { create(:product, stock_quantity: 10) }
  let(:order) { create(:order, :shipped, user: customer_user) }
  let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2) }

  describe '.deliver_order' do
    context 'when order can be delivered' do
      it 'delivers the order successfully' do
        result = described_class.deliver_order(
          order,
          admin_user,
          delivery_notes: 'Delivered to front door',
          delivery_signature: 'John Doe'
        )

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Order delivered successfully')

        order.reload
        expect(order.status).to eq('delivered')
        expect(order.delivery_notes).to eq('Delivered to front door')
        expect(order.delivery_signature).to eq('John Doe')
        expect(order.delivered_at).to be_present
      end

      it 'delivers the order without delivery info' do
        result = described_class.deliver_order(order, admin_user)

        expect(result[:success]).to be true

        order.reload
        expect(order.status).to eq('delivered')
        expect(order.delivery_notes).to be_nil
        expect(order.delivery_signature).to be_nil
        expect(order.delivered_at).to be_present
      end

      it 'creates notifications for customer and admins' do
        # Create another admin user to receive admin notification
        create(:user, role: 'admin')

        expect do
          described_class.deliver_order(order, admin_user, delivery_notes: 'Delivered successfully')
        end.to change(Notification, :count).by(2)

        customer_notification = Notification.find_by(user: customer_user, notification_type: 'order_delivered')
        expect(customer_notification).to be_present
        expect(customer_notification.message).to include('has been delivered successfully')
        expect(customer_notification.metadata['delivery_notes']).to eq('Delivered successfully')

        admin_notification = Notification.find_by(notification_type: 'order_delivered_admin')
        expect(admin_notification).to be_present
      end
    end

    context 'when order cannot be delivered' do
      it 'returns error for confirmed order' do
        order.update!(status: 'confirmed')

        result = described_class.deliver_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be delivered')
        expect(result[:details]).to include('Only shipped orders can be delivered')
      end

      it 'returns error for already delivered order' do
        order.update!(status: 'delivered')

        result = described_class.deliver_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be delivered')
      end

      it 'returns error for order without items' do
        order.order_items.destroy_all

        result = described_class.deliver_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be delivered')
        expect(result[:details]).to eq('Order has no items')
      end

      it 'returns error when order is nil' do
        result = described_class.deliver_order(nil, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order not found')
      end

      it 'returns error when user is nil' do
        result = described_class.deliver_order(order, nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end

    context 'when an error occurs' do
      before do
        allow(order).to receive(:update!).and_raise(StandardError.new('Database error'))
      end

      it 'handles errors gracefully' do
        result = described_class.deliver_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to deliver order')
        expect(result[:details]).to eq('Database error')
      end
    end
  end
end
