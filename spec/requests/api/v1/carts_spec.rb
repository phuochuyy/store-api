require 'swagger_helper'

RSpec.describe 'Shopping cart API', type: :request do
  extend ContractSchemas

  let(:user) { create(:user) }
  let(:Authorization) { auth_headers(user)['Authorization'] }
  let(:product) { create(:product, price: 50.00, stock_quantity: 5) }
  let(:cart) { create(:cart, user: user) }

  path '/api/v1/carts' do
    get 'Get (or create) the current user cart' do
      tags 'Shopping Cart'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'cart retrieved' do
        schema envelope({ cart: ref('Cart') })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'cart', 'user_id')).to eq(user.id)
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/carts/{cart_id}/items' do
    parameter name: :cart_id, in: :path, type: :integer

    post 'Add a product to the cart' do
      tags 'Shopping Cart'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { cart_item: { type: :object, properties: { product_id: { type: :integer },
                                                                quantity: { type: :integer } } } }
      }

      let(:cart_id) { cart.id }
      let(:quantity) { 2 }
      let(:body) { { cart_item: { product_id: product.id, quantity: quantity } } }

      response '201', 'item added' do
        schema envelope({ cart: ref('Cart'), cart_items: { type: :array, items: ref('CartItem') } })

        run_test! do
          expect(cart.cart_items.sole).to have_attributes(product_id: product.id, quantity: 2)
          expect(cart.reload.total_amount).to eq(100.00)
        end
      end

      response '422', 'more than the available stock' do
        let(:quantity) { 6 }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Only 5 items available in stock')
          expect(cart.cart_items).to be_empty
        end
      end

      response '422', 'product is out of stock' do
        let(:product) { create(:product, :out_of_stock) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Product is out of stock')
        end
      end

      response '404', "another user's cart" do
        let(:cart_id) { create(:cart).id }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/carts/{cart_id}/items/{id}' do
    parameter name: :cart_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    let(:cart_id) { cart.id }
    let(:cart_item) { create(:cart_item, cart: cart, product: product, quantity: 1) }
    let(:id) { cart_item.id }

    patch 'Change the quantity of a cart item' do
      tags 'Shopping Cart'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { cart_item: { type: :object, properties: { quantity: { type: :integer } } } }
      }

      let(:body) { { cart_item: { quantity: 3 } } }

      response '200', 'quantity updated' do
        schema envelope({ cart: ref('Cart'), cart_items: { type: :array, items: ref('CartItem') } })

        run_test! do
          expect(cart_item.reload.quantity).to eq(3)
          expect(cart.reload.total_amount).to eq(150.00)
        end
      end
    end

    delete 'Remove an item from the cart' do
      tags 'Shopping Cart'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'item removed' do
        schema envelope({ cart: ref('Cart'), cart_items: { type: :array, items: ref('CartItem') } })

        run_test! do
          expect(cart.cart_items.reload).to be_empty
          expect(cart.reload.total_amount).to eq(0)
        end
      end
    end
  end
end
