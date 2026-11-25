require 'rails_helper'

# End-to-end order flows through the public API. Fulfillment (Order#status) and payment
# (Order#payment_status) move independently: paying never moves an order along or back, and
# shipping never needs the order to be paid first.
RSpec.describe 'Order lifecycle', type: :request do
  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:payment_method) { create(:payment_method, gateway_type: 'stripe') }
  # The last unit in stock: creating the order reserves it, leaving 0.
  let(:product) { create(:product, price: 120.00, stock_quantity: 1) }

  def api(verb, path, as:, body: nil)
    public_send(verb, path, params: body&.to_json, headers: auth_headers(as))
    expect(response).to have_http_status(:success), -> { "#{verb.upcase} #{path}: #{response.status} #{response.body}" }
    response.parsed_body['data']
  end

  def place_order
    api(:post, '/api/v1/orders', as: customer, body: {
          order: { customer_name: 'Jane Doe', customer_email: 'jane@example.com', customer_phone: '0900000000' },
          order_items: [{ product_id: product.id, quantity: 1 }]
        }).dig('order', 'id')
  end

  def pay(order_id)
    api(:post, '/api/v1/payments', as: customer,
                                   body: { order_id: order_id, payment: { payment_method_id: payment_method.id } })
  end

  def confirm(order_id)
    api(:post, "/api/v1/orders/#{order_id}/confirm", as: admin)
  end

  def ship(order_id)
    api(:post, "/api/v1/orders/#{order_id}/ship", as: admin, body: { tracking_number: 'TRK1', carrier: 'UPS' })
  end

  def deliver(order_id)
    api(:post, "/api/v1/orders/#{order_id}/deliver", as: admin)
  end

  def order_state(order_id)
    Order.find(order_id).then { |order| [order.status, order.payment_status] }
  end

  it 'prepaid: pay, then confirm, ship and deliver' do
    order_id = place_order
    expect(product.reload.stock_quantity).to eq(0)

    pay(order_id)
    expect(order_state(order_id)).to eq(%w[pending paid])

    confirm(order_id)
    expect(order_state(order_id)).to eq(%w[confirmed paid])

    ship(order_id)
    expect(order_state(order_id)).to eq(%w[shipped paid])

    deliver(order_id)
    expect(order_state(order_id)).to eq(%w[delivered paid])

    shown = api(:get, "/api/v1/orders/#{order_id}", as: customer)['order']
    expect(shown).to include('status' => 'delivered', 'payment_status' => 'paid')
  end

  it 'paid on delivery: ship first, pay afterwards' do
    order_id = place_order
    confirm(order_id)
    ship(order_id)
    deliver(order_id)
    expect(order_state(order_id)).to eq(%w[delivered unpaid])

    pay(order_id)
    expect(order_state(order_id)).to eq(%w[delivered paid])
  end

  it 'a refund after delivery keeps the order delivered' do
    order_id = place_order
    payment_id = pay(order_id).dig('payment', 'id')
    confirm(order_id)
    ship(order_id)
    deliver(order_id)

    api(:post, "/api/v1/payments/#{payment_id}/refund", as: admin,
                                                        body: { refund: { amount: 120.00, reason: 'Damaged' } })
    expect(order_state(order_id)).to eq(%w[delivered refunded])
  end

  it 'a cancelled order cannot be paid' do
    order_id = place_order
    api(:post, "/api/v1/orders/#{order_id}/cancel", as: admin, body: { reason: 'Customer request' })

    post '/api/v1/payments', params: { order_id: order_id, payment: { payment_method_id: payment_method.id } }.to_json,
                             headers: auth_headers(customer)

    expect(response).to have_http_status(:unprocessable_content)
    expect(Order.find(order_id).payments).to be_empty
    expect(order_state(order_id)).to eq(%w[cancelled unpaid])
  end

  it 'an order cannot be paid twice' do
    order_id = place_order
    pay(order_id)

    post '/api/v1/payments', params: { order_id: order_id, payment: { payment_method_id: payment_method.id } }.to_json,
                             headers: auth_headers(customer)

    expect(response).to have_http_status(:unprocessable_content)
    expect(Order.find(order_id).payments.count).to eq(1)
  end
end
