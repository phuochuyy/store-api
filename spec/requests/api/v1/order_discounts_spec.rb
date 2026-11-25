require 'rails_helper'

# Discount codes applied through the API. usage_limit caps how many orders can hold a code at
# once: applying it takes a use, removing it (or switching to another code) gives the use back.
RSpec.describe 'Order discounts', type: :request do
  let(:discount) { create(:discount, code: 'SAVE10', value: 10, usage_limit: 1) }

  def new_order = create(:order, :with_items, user: create(:user))

  def apply(order, code = discount.code)
    post "/api/v1/orders/#{order.id}/apply_discount", params: { discount_code: code }.to_json,
                                                      headers: auth_headers(order.user)
  end

  def remove(order)
    delete "/api/v1/orders/#{order.id}/remove_discount", headers: auth_headers(order.user)
  end

  it 'counts a use when a code is applied' do
    order = new_order
    apply(order)

    expect(response).to have_http_status(:ok)
    expect(discount.reload.used_count).to eq(1)
    expect(order.reload.discount_amount).to eq(20) # 10% of 2 x 100.00
  end

  it 'refuses the code once its usage limit is reached' do
    apply(new_order)
    other_order = new_order
    apply(other_order)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to eq('Discount usage limit reached')
    expect(other_order.reload.discount_id).to be_nil
    expect(discount.reload.used_count).to eq(1)
  end

  it 'does not count a second use when the same order applies the code again' do
    order = new_order
    apply(order)
    apply(order)

    expect(response).to have_http_status(:ok)
    expect(discount.reload.used_count).to eq(1)
  end

  it 'gives the use back when the discount is removed' do
    order = new_order
    apply(order)
    remove(order)

    expect(response).to have_http_status(:ok)
    expect(discount.reload.used_count).to eq(0)

    apply(new_order)
    expect(response).to have_http_status(:ok)
  end

  it 'gives the old code its use back when the order switches codes' do
    order = new_order
    apply(order)
    other = create(:discount, code: 'SAVE20', value: 20)
    apply(order, other.code)

    expect(response).to have_http_status(:ok)
    expect(order.reload.discount_code).to eq('SAVE20')
    expect(discount.reload.used_count).to eq(0)
    expect(other.reload.used_count).to eq(1)
  end
end
