require 'rails_helper'

# Every gateway type a payment method can have must be payable through the API. Online gateways
# settle at once; cash on delivery and bank transfers wait for an admin to confirm the money.
RSpec.describe 'Payment gateways', type: :request do
  outcomes = {
    'stripe' => { payment: 'completed', order: 'paid' },
    'paypal' => { payment: 'completed', order: 'paid' },
    'wallet' => { payment: 'completed', order: 'paid' },
    'bank_transfer' => { payment: 'pending', order: 'unpaid' },
    'cash_on_delivery' => { payment: 'pending', order: 'unpaid' }
  }

  let(:customer) { create(:user) }

  it 'covers every gateway type' do
    expect(outcomes.keys).to match_array(PaymentMethod.gateway_types.keys)
  end

  outcomes.each do |gateway_type, outcome|
    it "#{gateway_type}: the payment is #{outcome[:payment]} and the order #{outcome[:order]}" do
      order = create(:order, :with_items, user: customer, total_amount: 200.00)
      payment_method = create(:payment_method, gateway_type: gateway_type)

      body = { order_id: order.id, payment: { payment_method_id: payment_method.id } }
      post '/api/v1/payments', params: body.to_json, headers: auth_headers(customer)

      expect(response).to have_http_status(:created)
      expect(order.payments.sole.status).to eq(outcome[:payment])
      expect(order.reload.payment_status).to eq(outcome[:order])
    end
  end
end
