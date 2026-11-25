require 'swagger_helper'

RSpec.describe 'Returns API', type: :request do
  extend ContractSchemas

  def self.data_envelope(data)
    {
      type: :object,
      required: %w[success data message],
      properties: { success: { type: :boolean, enum: [true] }, message: { type: :string }, data: data }
    }
  end

  let(:customer) { create(:user) }
  let(:other_customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:Authorization) { auth_headers(customer)['Authorization'] }
  let(:admin_authorization) { auth_headers(admin)['Authorization'] }

  let(:product) { create(:product, stock_quantity: 10) }
  let(:order) { create(:order, :delivered, user: customer) }
  let(:order_item) { create(:order_item, order: order, product: product, quantity: 2, unit_price: 100.00) }

  def create_return_request(status: 'pending', owner: customer, owner_order: order, item: order_item)
    ReturnRequest.create!(order: owner_order, user: owner, reason: 'Screen arrived cracked', status: status).tap do |rr|
      ReturnItem.create!(return_request: rr, order_item: item, quantity: 1, reason: 'Cracked', condition: 'unopened')
    end
  end

  path '/api/v1/returns' do
    get "List the current user's return requests" do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let!(:own_return) { create_return_request }

      before do
        other_order = create(:order, :delivered, user: other_customer)
        create_return_request(owner: other_customer, owner_order: other_order,
                              item: create(:order_item, order: other_order))
      end

      response '200', 'only the caller\'s return requests' do
        schema data_envelope({ type: :array, items: ref('ReturnRequest') })

        run_test! do |response|
          expect(response.parsed_body['data'].pluck('id')).to eq([own_return.id])
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    post 'Request a return for a delivered order' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order_id: { type: :integer },
          reason: { type: :string },
          return_type: { type: :string, enum: %w[refund exchange] },
          return_items: { type: :array, items: { type: :object } }
        }
      }

      let(:body) do
        {
          order_id: order.id,
          reason: 'Screen arrived cracked',
          return_type: 'refund',
          return_items: [{ order_item_id: order_item.id, quantity: 1, reason: 'Cracked', condition: 'opened' }]
        }
      end

      response '201', 'return requested' do
        schema data_envelope(ref('ReturnRequest'))

        run_test! do |response|
          data = response.parsed_body['data']
          expect(data).to include('status' => 'pending', 'refund_amount' => '80.0', 'total_quantity' => 1)
          expect(customer.return_requests.sole.return_items.sole).to have_attributes(condition: 'opened')
        end
      end

      response '404', "another user's order" do
        let(:order) { create(:order, :delivered, user: other_customer) }

        schema ref('ErrorResponse')
        run_test! do
          expect(ReturnRequest.count).to eq(0)
        end
      end

      response '422', 'order not delivered yet' do
        let(:order) { create(:order, user: customer, status: 'shipped') }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order cannot be returned')
          expect(ReturnRequest.count).to eq(0)
        end
      end
    end
  end

  path '/api/v1/returns/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:return_request) { create_return_request }
    let(:id) { return_request.id }

    get 'Show a return request' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'owner' do
        schema data_envelope(ref('ReturnRequest'))
        run_test!
      end

      response '200', 'admin' do
        let(:Authorization) { admin_authorization }

        schema data_envelope(ref('ReturnRequest'))
        run_test!
      end

      response '404', 'another customer' do
        let(:Authorization) { auth_headers(other_customer)['Authorization'] }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/returns/{id}/cancel' do
    parameter name: :id, in: :path, type: :integer

    let(:return_request) { create_return_request }
    let(:id) { return_request.id }

    patch 'Cancel a return request (owner)' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'cancelled by the owner' do
        schema data_envelope(ref('ReturnRequest'))
        run_test! do
          expect(return_request.reload).to be_cancelled
        end
      end

      response '404', 'another customer cannot cancel it' do
        let(:Authorization) { auth_headers(other_customer)['Authorization'] }

        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to be_pending
        end
      end
    end
  end

  path '/api/v1/returns/{id}/approve' do
    parameter name: :id, in: :path, type: :integer

    let(:return_request) { create_return_request }
    let(:id) { return_request.id }

    patch 'Approve a return request (admin only)' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: { type: :object, properties: { admin_notes: { type: :string } } }

      let(:body) { { admin_notes: 'Photo confirms damage' } }

      response '200', 'approved by an admin' do
        let(:Authorization) { admin_authorization }

        schema data_envelope(ref('ReturnRequest'))
        run_test! do
          expect(return_request.reload).to have_attributes(status: 'approved', admin_notes: 'Photo confirms damage')
        end
      end

      response '403', 'the owner cannot approve their own return' do
        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to have_attributes(status: 'pending', approved_at: nil, admin_notes: nil)
        end
      end

      response '422', 'already rejected' do
        let(:Authorization) { admin_authorization }
        let(:return_request) { create_return_request(status: 'rejected') }

        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to be_rejected
        end
      end
    end
  end

  path '/api/v1/returns/{id}/reject' do
    parameter name: :id, in: :path, type: :integer

    let(:return_request) { create_return_request }
    let(:id) { return_request.id }

    patch 'Reject a return request (admin only)' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: { type: :object, properties: { rejection_reason: { type: :string } } }

      let(:body) { { rejection_reason: 'Outside the return policy' } }

      response '200', 'rejected by an admin' do
        let(:Authorization) { admin_authorization }

        schema data_envelope(ref('ReturnRequest'))
        run_test! do
          expect(return_request.reload).to have_attributes(status: 'rejected',
                                                           rejection_reason: 'Outside the return policy')
        end
      end

      response '400', 'rejection reason missing' do
        let(:Authorization) { admin_authorization }
        let(:body) { {} }

        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to be_pending
        end
      end

      response '403', 'the owner cannot reject their own return' do
        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to have_attributes(status: 'pending', rejection_reason: nil)
        end
      end
    end
  end

  path '/api/v1/returns/{id}/complete' do
    parameter name: :id, in: :path, type: :integer

    let(:return_request) { create_return_request(status: 'approved') }
    let(:id) { return_request.id }

    patch 'Complete an approved return: restock the items (admin only)' do
      tags 'Returns'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'completed by an admin' do
        let(:Authorization) { admin_authorization }

        schema data_envelope(ref('ReturnRequest'))
        run_test! do
          expect(return_request.reload).to be_completed
          expect(product.reload.stock_quantity).to eq(11)
        end
      end

      response '403', 'the owner cannot complete their own return' do
        schema ref('ErrorResponse')
        run_test! do
          expect(return_request.reload).to be_approved
          expect(product.reload.stock_quantity).to eq(10)
        end
      end

      response '422', 'not approved yet' do
        let(:Authorization) { admin_authorization }
        let(:return_request) { create_return_request(status: 'pending') }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Return request must be approved')
          expect(product.reload.stock_quantity).to eq(10)
        end
      end
    end
  end
end
