require 'rails_helper'

# Guards the rescue_from ordering in ErrorHandling: specific handlers must win over the
# StandardError catch-all, which rescue_from consults first when it is declared last.
RSpec.describe 'API error handling', type: :request do
  let(:user) { create(:user) }

  it 'maps ActiveRecord::RecordNotFound to 404 without leaking SQL' do
    get '/api/v1/carts/0/items', headers: auth_headers(user)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to include('success' => false, 'message' => 'Cart not found')
    expect(response.body).not_to include('WHERE')
  end

  it 'maps ActionController::ParameterMissing to 400' do
    cart = create(:cart, user: user)
    item = create(:cart_item, cart: cart)

    patch "/api/v1/carts/#{cart.id}/items/#{item.id}", params: {}.to_json, headers: auth_headers(user)

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to include('success' => false, 'message' => 'Missing parameter')
  end
end
