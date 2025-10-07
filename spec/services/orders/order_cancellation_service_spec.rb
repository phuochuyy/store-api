# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::OrderCancellationService do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:product) { create(:product, stock_quantity: 10) }
  let(:order) { create(:order, user: customer_user, status: 'pending') }
  let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2) }

  describe '.cancel_order' do
    context 'with valid order and user' do
      it 'cancels the order successfully' do
        result = described_class.cancel_order(order, admin_user, 'Customer requested')

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Order cancelled successfully')
        expect(order.reload.status).to eq('cancelled')
        expect(order.cancelled_at).to be_present
        expect(order.cancellation_reason).to eq('Customer requested')
      end

      it 'restores stock quantities' do
        expect do
          described_class.cancel_order(order, admin_user)
        end.to change { product.reload.stock_quantity }.by(2)
      end

      it 'creates notification for customer' do
        expect do
          described_class.cancel_order(order, admin_user, 'Out of stock')
        end.to change { Notification.count }.by(1)

        notification = Notification.last
        expect(notification.user).to eq(customer_user)
        expect(notification.notification_type).to eq('order_cancelled')
        expect(notification.title).to eq('Order Cancelled')
        expect(notification.metadata['reason']).to eq('Out of stock')
      end

      it 'creates notification for other admins' do
        other_admin = create(:user, role: 'admin')

        expect do
          described_class.cancel_order(order, admin_user, 'Customer requested')
        end.to change { Notification.count }.by(2)

        admin_notification = Notification.where(notification_type: 'order_cancelled_admin').last
        expect(admin_notification.user).to eq(other_admin)
        expect(admin_notification.metadata['cancelled_by']).to eq(admin_user.name)
        expect(admin_notification.metadata['reason']).to eq('Customer requested')
      end
    end

    context 'with different order statuses' do
      it 'allows cancellation of confirmed orders' do
        order.update!(status: 'confirmed')
        result = described_class.cancel_order(order, admin_user)

        expect(result[:success]).to be true
        expect(order.reload.status).to eq('cancelled')
      end

      it 'allows cancellation of shipped orders' do
        order.update!(status: 'shipped')
        result = described_class.cancel_order(order, admin_user)

        expect(result[:success]).to be true
        expect(order.reload.status).to eq('cancelled')
      end

      it 'prevents cancellation of delivered orders' do
        order.update!(status: 'delivered')
        result = described_class.cancel_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be cancelled')
        expect(result[:details]).to include('Order is currently delivered')
      end

      it 'prevents cancellation of already cancelled orders' do
        order.update!(status: 'cancelled')
        result = described_class.cancel_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be cancelled')
        expect(result[:details]).to include('Order is currently cancelled')
      end
    end

    context 'with invalid order' do
      it 'returns error when order is nil' do
        result = described_class.cancel_order(nil, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order not found')
      end
    end

    context 'with invalid user' do
      it 'returns error when user is nil' do
        result = described_class.cancel_order(order, nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end

    context 'with database error' do
      it 'handles database errors gracefully' do
        allow(order).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(order))

        result = described_class.cancel_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to cancel order')
        expect(result[:details]).to be_present
      end
    end
  end
end
