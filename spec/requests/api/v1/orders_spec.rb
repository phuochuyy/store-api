require 'swagger_helper'

RSpec.describe 'Orders API (checkout)', type: :request do
  extend ContractSchemas

  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:current_user) { customer }
  let(:Authorization) { auth_headers(current_user)['Authorization'] }

  let(:phone) { create(:product, price: 100.00, stock_quantity: 5) }
  let(:case_product) { create(:product, price: 20.00, stock_quantity: 1) }

  let(:customer_fields) do
    { customer_name: 'Jane Doe', customer_email: 'jane@example.com', customer_phone: '0900000000' }
  end

  # Builds an order through the real checkout service so stock and stock movements are realistic.
  def place_order(user, items)
    result = Orders::OrderCreationService.create_order(customer_fields.merge(user_id: user.id), items)
    raise "checkout failed: #{result.inspect}" unless result[:success]

    result[:order]
  end

  path '/api/v1/orders' do
    post 'Place an order (checkout)' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order: { type: :object },
          order_items: { type: :array, items: { type: :object } }
        }
      }

      let(:order_items) do
        [{ product_id: phone.id, quantity: 2 }, { product_id: case_product.id, quantity: 1 }]
      end
      let(:body) { { order: customer_fields, order_items: order_items } }

      response '201', 'order placed' do
        schema envelope({ order: ref('Order') })

        run_test! do |response|
          order = Order.find(response.parsed_body.dig('data', 'order', 'id'))

          expect(order).to have_attributes(user_id: customer.id, status: 'pending', total_amount: 220.00)
          expect(order.order_items.count).to eq(2)
          expect(phone.reload.stock_quantity).to eq(3)
          expect(case_product.reload.stock_quantity).to eq(0)
          expect(StockMovement.where(product: phone).sole).to have_attributes(quantity: -2, new_quantity: 3)
        end
      end

      response '201', 'client-supplied status is ignored' do
        let(:body) { { order: customer_fields.merge(status: 'paid'), order_items: order_items } }

        schema envelope({ order: ref('Order') })
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'order', 'status')).to eq('pending')
        end
      end

      response '422', 'one item is out of stock: nothing is reserved' do
        let(:order_items) do
          [{ product_id: phone.id, quantity: 2 }, { product_id: case_product.id, quantity: 2 }]
        end

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['errors'].join).to include('Insufficient stock')
          expect(Order.count).to eq(0)
          # The first item's reservation is rolled back together with the failed second item.
          expect(phone.reload.stock_quantity).to eq(5)
          expect(StockMovement.count).to eq(0)
        end
      end

      response '401', 'not signed in' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    get "List the current user's orders" do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'only own orders' do
        before do
          place_order(customer, [{ product_id: phone.id, quantity: 1 }])
          place_order(create(:user), [{ product_id: phone.id, quantity: 1 }])
        end

        schema envelope({ orders: { type: :array, items: ref('Order') }, pagination: ref('Pagination') })
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'orders').size).to eq(1)
        end
      end
    end
  end

  path '/api/v1/orders/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Show an order' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let(:order) { place_order(customer, [{ product_id: phone.id, quantity: 1 }]) }
      let(:id) { order.id }

      response '200', 'own order' do
        schema envelope({ order: ref('Order'), order_items: { type: :array, items: ref('OrderItem') } })
        run_test!
      end

      response '404', "another customer's order" do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}/cancel' do
    parameter name: :id, in: :path, type: :integer

    post 'Cancel an order and release its stock' do
      tags 'Orders'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let(:current_user) { admin }
      let(:order) { place_order(customer, [{ product_id: phone.id, quantity: 2 }]) }
      let(:id) { order.id }

      response '200', 'cancelled; product stock restored' do
        schema envelope({ order: ref('Order') })
        run_test! do
          expect(order.reload.status).to eq('cancelled')
          expect(phone.reload.stock_quantity).to eq(5)
        end
      end

      response '200', 'cancelled; variant stock restored to the variant' do
        let(:variant) { create(:product_variant, product: phone, stock_quantity: 4) }
        let(:order) { place_order(customer, [{ product_id: phone.id, product_variant_id: variant.id, quantity: 3 }]) }

        schema envelope({ order: ref('Order') })
        run_test! do
          expect(variant.reload.stock_quantity).to eq(4)
          expect(phone.reload.stock_quantity).to eq(5)
        end
      end

      response '422', 'already delivered' do
        before { order.update!(status: 'delivered', delivered_at: Time.current) }

        schema ref('ErrorResponse')
        run_test! do
          expect(phone.reload.stock_quantity).to eq(3)
        end
      end

      response '403', 'customers cannot cancel' do
        let(:current_user) { customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(order.reload.status).to eq('pending')
        end
      end
    end
  end
end
