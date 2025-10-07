# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::OrderConfirmationService do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:product) { create(:product, stock_quantity: 10) }
  let(:order) { create(:order, user: customer_user, status: 'pending') }
  let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2) }

  describe '.confirm_order' do
    context 'with valid order and user' do
      it 'confirms the order successfully' do
        result = described_class.confirm_order(order, admin_user)

        puts "Result: #{result.inspect}"
        puts "Order status: #{order.reload.status}"
        puts "Order items count: #{order.order_items.count}"

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Order confirmed successfully')
        expect(order.reload.status).to eq('confirmed')
        expect(order.confirmed_at).to be_present
      end

      it 'creates notification for customer' do
        expect do
          described_class.confirm_order(order, admin_user)
        end.to change { Notification.count }.by(1)

        notification = Notification.last
        expect(notification.user).to eq(customer_user)
        expect(notification.notification_type).to eq('order_confirmed')
        expect(notification.title).to eq('Order Confirmed')
        expect(notification.metadata['order_id']).to eq(order.id)
        expect(notification.metadata['confirmed_by']).to eq(admin_user.name)
      end

      it 'creates notification for other admins' do
        other_admin = create(:user, role: 'admin')

        expect do
          described_class.confirm_order(order, admin_user)
        end.to change { Notification.count }.by(2)

        admin_notification = Notification.where(notification_type: 'order_confirmed_admin').last
        expect(admin_notification.user).to eq(other_admin)
        expect(admin_notification.metadata['confirmed_by']).to eq(admin_user.name)
      end
    end

    context 'with invalid order' do
      it 'returns error when order is nil' do
        result = described_class.confirm_order(nil, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order not found')
      end

      it 'returns error when order is not pending' do
        order.update!(status: 'confirmed')
        result = described_class.confirm_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be confirmed')
        expect(result[:details]).to include('Order is currently confirmed')
      end

      it 'returns error when order has no items' do
        order.order_items.destroy_all
        result = described_class.confirm_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be confirmed')
        expect(result[:details]).to eq('Order has no items')
      end

      it 'returns error when product is out of stock' do
        product.update!(stock_quantity: 1)
        result = described_class.confirm_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be confirmed')
        expect(result[:details]).to include(product.name)
      end

      it 'returns error when product is deleted' do
        product.destroy
        result = described_class.confirm_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be confirmed')
        expect(result[:details]).to include("Product ID #{order_item.product_id}")
      end
    end

    context 'with invalid user' do
      it 'returns error when user is nil' do
        result = described_class.confirm_order(order, nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end

    context 'with database error' do
      it 'handles database errors gracefully' do
        allow(order).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(order))

        result = described_class.confirm_order(order, admin_user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to confirm order')
        expect(result[:details]).to be_present
      end
    end
  end
end
