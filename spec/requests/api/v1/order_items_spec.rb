require 'swagger_helper'

RSpec.describe 'Order items API', type: :request do
  extend ContractSchemas

  let(:customer) { create(:user) }
  let(:other_customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:current_user) { customer }
  let(:Authorization) { auth_headers(current_user)['Authorization'] }

  let(:product) { create(:product, price: 50.00, stock_quantity: 10) }
  let(:order) { create(:order, user: customer) }
  let!(:order_item) { create(:order_item, order: order, product: product, quantity: 2, unit_price: 50.00) }

  path '/api/v1/orders/{order_id}/items' do
    parameter name: :order_id, in: :path, type: :integer

    let(:order_id) { order.id }

    get 'List the items of an order (owner or admin)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'the customer who owns the order' do
        schema envelope({ order_items: { type: :array, items: ref('OrderItem') } })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'order_items').pluck('id')).to eq([order_item.id])
        end
      end

      response '200', 'an admin' do
        let(:current_user) { admin }

        schema envelope({ order_items: { type: :array, items: ref('OrderItem') } })
        run_test!
      end

      response '404', "another customer's order" do
        let(:current_user) { other_customer }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body).not_to have_key('data')
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    post 'Add an item to an order (admin only)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { order_item: { type: :object, properties: { product_id: { type: :integer },
                                                                 quantity: { type: :integer } } } }
      }

      let(:extra_product) { create(:product, price: 30.00) }
      let(:body) { { order_item: { product_id: extra_product.id, quantity: 1 } } }

      response '201', 'added by an admin, priced from the product' do
        let(:current_user) { admin }

        schema envelope({ order_item: ref('OrderItem') })
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'order_item', 'unit_price')).to eq('30.0')
          expect(order.order_items.count).to eq(2)
          expect(order.reload.total_amount).to eq(130.00)
          expect(extra_product.reload.stock_quantity).to eq(9)
        end
      end

      response '422', 'not enough stock left' do
        let(:current_user) { admin }
        let(:extra_product) { create(:product, price: 30.00, stock_quantity: 0) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to include('Not enough stock')
          expect(order.order_items.count).to eq(1)
        end
      end

      response '422', 'the order has already shipped' do
        let(:current_user) { admin }
        let(:order) { create(:order, :shipped, user: customer) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq(Order::ITEMS_LOCKED_ERROR)
          expect(order.order_items.count).to eq(1)
          expect(extra_product.reload.stock_quantity).to eq(10)
        end
      end

      response '403', 'the customer who owns the order' do
        schema ref('ErrorResponse')
        run_test! do
          expect(order.order_items.count).to eq(1)
        end
      end

      response '403', "another customer's order" do
        let(:current_user) { other_customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(order.order_items.count).to eq(1)
        end
      end

      response '404', 'unknown order' do
        let(:current_user) { admin }
        let(:order_id) { 0 }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/orders/items/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:id) { order_item.id }

    get 'Show an order item (owner or admin)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'the customer who owns the order' do
        schema envelope({ order_item: ref('OrderItem') })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'order_item')).to include('id' => order_item.id, 'quantity' => 2,
                                                                            'total_price' => '100.0')
        end
      end

      response '200', 'an admin' do
        let(:current_user) { admin }

        schema envelope({ order_item: ref('OrderItem') })
        run_test!
      end

      # 404, not 403, so the existence of another user's order item is not confirmed.
      response '404', "another customer's order item" do
        let(:current_user) { other_customer }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body).not_to have_key('data')
        end
      end
    end

    patch 'Change the quantity of an order item (admin only)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { order_item: { type: :object, properties: { quantity: { type: :integer } } } }
      }

      let(:body) { { order_item: { quantity: 3 } } }

      response '200', 'updated by an admin; the order total follows' do
        let(:current_user) { admin }

        schema envelope({ order_item: ref('OrderItem') })
        run_test! do
          expect(order_item.reload.quantity).to eq(3)
          expect(order.reload.total_amount).to eq(150.00)
          expect(product.reload.stock_quantity).to eq(9)
        end
      end

      response '200', 'fewer units give the stock back' do
        let(:current_user) { admin }
        let(:body) { { order_item: { quantity: 1 } } }

        schema envelope({ order_item: ref('OrderItem') })
        run_test! do
          expect(order_item.reload.quantity).to eq(1)
          expect(product.reload.stock_quantity).to eq(11)
        end
      end

      response '422', 'more units than the stock left' do
        let(:current_user) { admin }
        let(:body) { { order_item: { quantity: 13 } } }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to include('Not enough stock')
          expect(order_item.reload.quantity).to eq(2)
          expect(product.reload.stock_quantity).to eq(10)
        end
      end

      response '422', 'the order has already shipped' do
        let(:current_user) { admin }
        let(:order) { create(:order, :shipped, user: customer) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq(Order::ITEMS_LOCKED_ERROR)
          expect(order_item.reload.quantity).to eq(2)
          expect(product.reload.stock_quantity).to eq(10)
        end
      end

      # Changing the product would keep the old unit price, so it is not accepted.
      response '200', 'the product cannot be swapped' do
        let(:current_user) { admin }
        let(:body) { { order_item: { quantity: 2, product_id: create(:product, price: 999.00).id } } }

        schema envelope({ order_item: ref('OrderItem') })
        run_test! do
          expect(order_item.reload).to have_attributes(product_id: product.id, unit_price: 50.00)
        end
      end

      response '403', 'the customer who owns the order' do
        schema ref('ErrorResponse')
        run_test! do
          expect(order_item.reload.quantity).to eq(2)
        end
      end

      response '403', "another customer's order item" do
        let(:current_user) { other_customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(order_item.reload.quantity).to eq(2)
        end
      end

      response '422', 'invalid quantity' do
        let(:current_user) { admin }
        let(:body) { { order_item: { quantity: 0 } } }

        schema ref('ErrorResponse')
        run_test! do
          expect(order_item.reload.quantity).to eq(2)
        end
      end
    end

    delete 'Remove an item from an order (admin only)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'removed by an admin; the order total follows' do
        let(:current_user) { admin }

        schema type: :object, required: %w[success message],
               properties: { success: { type: :boolean, enum: [true] }, message: { type: :string } }
        run_test! do
          expect(OrderItem.exists?(order_item.id)).to be false
          expect(order.reload.total_amount).to eq(0)
          expect(product.reload.stock_quantity).to eq(12)
        end
      end

      response '422', 'the order has already shipped' do
        let(:current_user) { admin }
        let(:order) { create(:order, :shipped, user: customer) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq(Order::ITEMS_LOCKED_ERROR)
          expect(OrderItem.exists?(order_item.id)).to be true
          expect(product.reload.stock_quantity).to eq(10)
        end
      end

      response '403', 'the customer who owns the order' do
        schema ref('ErrorResponse')
        run_test! do
          expect(OrderItem.exists?(order_item.id)).to be true
        end
      end

      response '403', "another customer's order item" do
        let(:current_user) { other_customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(OrderItem.exists?(order_item.id)).to be true
        end
      end
    end
  end

  # The nested route names the order; an item of another order is not found through it.
  path '/api/v1/orders/{order_id}/items/{id}' do
    parameter name: :order_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show an order item through its order (owner or admin)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let(:current_user) { admin }
      let(:id) { order_item.id }

      response '200', 'the item belongs to the order' do
        let(:order_id) { order.id }

        schema envelope({ order_item: ref('OrderItem') })
        run_test!
      end

      response '404', 'the item belongs to another order' do
        let(:order_id) { create(:order, user: customer).id }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order item not found')
        end
      end
    end
  end
end
