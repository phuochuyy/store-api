require 'rails_helper'

RSpec.describe Payment do
  describe 'keeping the order payment status in step' do
    let(:order) { create(:order, status: 'confirmed', total_amount: 100.00) }
    let(:payment) { create(:payment, order: order, status: 'pending', amount: 100.00) }

    def order_state = order.reload.then { |o| [o.status, o.payment_status] }

    it 'marks the order paid without moving its fulfillment status' do
      payment.update!(status: 'completed')

      expect(order_state).to eq(%w[confirmed paid])
    end

    it 'records a failed attempt, and a later successful one' do
      payment.update!(status: 'failed')
      expect(order_state).to eq(%w[confirmed payment_failed])

      create(:payment, order: order, status: 'pending', amount: 100.00).update!(status: 'completed')
      expect(order_state).to eq(%w[confirmed paid])
    end

    it 'does not downgrade a paid order when another attempt fails' do
      payment.update!(status: 'completed')
      create(:payment, order: order, status: 'pending', amount: 100.00).update!(status: 'failed')

      expect(order_state).to eq(%w[confirmed paid])
    end

    it 'records full and partial refunds without moving the fulfillment status' do
      order.update!(status: 'delivered')
      payment.update!(status: 'completed')

      payment.update!(status: 'partially_refunded')
      expect(order_state).to eq(%w[delivered partially_refunded])

      payment.update!(status: 'refunded')
      expect(order_state).to eq(%w[delivered refunded])
    end
  end
end
