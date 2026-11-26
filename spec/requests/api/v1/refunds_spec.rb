require 'rails_helper'

# Money goes back when a paid order is cancelled, and when a return is completed.
RSpec.describe 'Refunds', type: :request do
  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:product) { create(:product, price: 100.00, stock_quantity: 5) }
  let(:order) do
    Orders::OrderCreationService.create_order(
      { customer_name: 'Jane Doe', customer_email: 'jane@example.com', customer_phone: '0900000000',
        user_id: customer.id },
      [{ product_id: product.id, quantity: 2 }]
    ).fetch(:order)
  end

  def pay(gateway_type)
    method = create(:payment_method, gateway_type: gateway_type)
    Payments::PaymentProcessorService.process_payment(order: order, payment_method: method).fetch(:payment)
  end

  def cancel
    post "/api/v1/orders/#{order.id}/cancel", params: { reason: 'Customer request' }.to_json,
                                              headers: auth_headers(admin)
  end

  describe 'cancelling an order' do
    it 'refunds a card payment in full' do
      payment = pay('stripe')
      cancel

      expect(response).to have_http_status(:ok)
      expect(payment.reload.status).to eq('refunded')
      expect(order.reload).to have_attributes(status: 'cancelled', payment_status: 'refunded')
    end

    it 'cancels a cash on delivery payment that was never collected' do
      payment = pay('cash_on_delivery')
      cancel

      expect(response).to have_http_status(:ok)
      expect(payment.reload.status).to eq('cancelled')
      expect(order.reload).to have_attributes(status: 'cancelled', payment_status: 'unpaid')
    end

    it 'leaves collected cash to be refunded by hand, and says so' do
      payment = pay('cash_on_delivery')
      Payments::PaymentProcessorService.confirm_offline_payment(payment: payment, confirmed_by: admin)
      cancel

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['message']).to include('refund by hand')
      expect(payment.reload.status).to eq('completed')
      expect(order.reload).to have_attributes(status: 'cancelled', payment_status: 'paid')
    end

    it 'gives the discount use back' do
      discount = create(:discount, usage_limit: 1)
      order.apply_discount(discount.code)
      cancel

      expect(response).to have_http_status(:ok)
      expect(discount.reload.used_count).to eq(0)
    end
  end

  describe 'completing a return' do
    def return_one_unit
      order.update!(status: 'delivered', delivered_at: Time.current)
      attributes = { order: order, user: customer, reason: 'Screen arrived cracked', status: 'approved' }
      ReturnRequest.create!(attributes).tap do |rr|
        ReturnItem.create!(return_request: rr, order_item: order.order_items.first, quantity: 1,
                           reason: 'Cracked', condition: 'unopened')
        rr.update!(refund_amount: rr.calculate_refund_amount)
      end
    end

    def complete(return_request)
      patch "/api/v1/returns/#{return_request.id}/complete", headers: auth_headers(admin)
    end

    it 'refunds the returned unit on the card payment' do
      payment = pay('stripe')
      return_request = return_one_unit
      complete(return_request)

      expect(response).to have_http_status(:ok)
      expect(payment.reload.status).to eq('partially_refunded')
      expect(payment.metadata['refund_amount'].to_d).to eq(100.00)
      expect(order.reload.payment_status).to eq('partially_refunded')
    end

    it 'leaves collected cash to be refunded by hand, and says so' do
      payment = pay('cash_on_delivery')
      Payments::PaymentProcessorService.confirm_offline_payment(payment: payment, confirmed_by: admin)
      complete(return_one_unit)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['message']).to include('refund by hand')
      expect(payment.reload.status).to eq('completed')
    end
  end
end
