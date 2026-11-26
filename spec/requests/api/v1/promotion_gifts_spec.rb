require 'rails_helper'

# Promotions that give products away. A gift leaves stock like any unit sold, and it is free.
RSpec.describe 'Promotion gifts', type: :request do
  let(:customer) { create(:user) }
  let(:phone) { create(:product, price: 500.00, stock_quantity: 10) }
  let(:phone_case) { create(:product, price: 20.00, stock_quantity: 3) }
  let(:order) do
    Orders::OrderCreationService.create_order(
      { customer_name: 'Jane Doe', customer_email: 'jane@example.com', customer_phone: '0900000000',
        user_id: customer.id },
      [{ product_id: phone.id, quantity: 2 }]
    ).fetch(:order)
  end

  def promotion(type, benefits)
    Promotion.create!(name: 'Gift', promotion_type: type, conditions: {}, benefits: benefits, usage_limit: 10)
  end

  def apply(promotion)
    post "/api/v1/promotions/#{promotion.id}/apply", params: { order_id: order.id }.to_json,
                                                     headers: auth_headers(customer)
  end

  it 'free gift: the gift leaves stock and costs nothing' do
    apply(promotion('free_gift', { gift_product_id: phone_case.id, gift_quantity: 1 }))

    expect(response).to have_http_status(:ok)
    expect(phone_case.reload.stock_quantity).to eq(2)
    expect(order.reload.total_amount).to eq(1000.00)
    expect(order.order_items.find_by(product: phone_case).unit_price).to eq(0)
  end

  it 'buy 2 get 1: the free unit leaves stock and is not charged' do
    apply(promotion('buy_x_get_y', { buy_quantity: 2, get_quantity: 1 }))

    expect(response).to have_http_status(:ok)
    expect(phone.reload.stock_quantity).to eq(7)
    expect(order.reload.total_amount).to eq(1000.00)
    expect(order.order_items.sum(:quantity)).to eq(3)
  end

  it 'cancelling the order puts the gift back in stock' do
    apply(promotion('free_gift', { gift_product_id: phone_case.id, gift_quantity: 1 }))
    post "/api/v1/orders/#{order.id}/cancel", params: { reason: 'Changed my mind' }.to_json,
                                              headers: auth_headers(create(:user, :admin))

    expect(response).to have_http_status(:ok)
    expect(phone_case.reload.stock_quantity).to eq(3)
    expect(phone.reload.stock_quantity).to eq(10)
  end

  it 'refuses a gift that is out of stock, and changes nothing' do
    phone_case.update!(stock_quantity: 0)
    gift = promotion('free_gift', { gift_product_id: phone_case.id, gift_quantity: 1 })
    apply(gift)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to include('Not enough stock')
    expect(order.reload.order_items.count).to eq(1)
    expect(gift.reload.used_count).to eq(0)
  end
end
