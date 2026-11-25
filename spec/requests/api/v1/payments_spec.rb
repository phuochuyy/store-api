require 'swagger_helper'

RSpec.describe 'Payments API (checkout)', type: :request do
  extend ContractSchemas

  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:current_user) { customer }
  let(:Authorization) { auth_headers(current_user)['Authorization'] }

  let(:product) { create(:product, price: 100.00, stock_quantity: 5) }
  let(:payment_method) { create(:payment_method, gateway_type: 'stripe') }
  let(:order) do
    Orders::OrderCreationService.create_order(
      { customer_name: 'Jane Doe', customer_email: 'jane@example.com', customer_phone: '0900000000',
        user_id: customer.id },
      [{ product_id: product.id, quantity: 1 }]
    ).fetch(:order)
  end

  path '/api/v1/payments' do
    post 'Pay for an order' do
      tags 'Payments'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order_id: { type: :integer },
          payment: { type: :object, properties: { payment_method_id: { type: :integer } } }
        }
      }

      let(:body) { { order_id: order.id, payment: { payment_method_id: payment_method.id } } }

      response '201', 'payment completed; order marked paid' do
        schema envelope({ payment: ref('Payment'), order: ref('Order') })

        run_test! do
          payment = order.payments.sole
          expect(payment).to have_attributes(status: 'completed', amount: 100.00)
          expect(payment.transaction_id).to be_present
          expect(order.reload).to have_attributes(payment_status: 'paid', status: 'pending')
        end
      end

      response '201', 'cash on delivery: recorded as pending; the order stays unpaid until an admin confirms' do
        let(:payment_method) { create(:payment_method, :cash_on_delivery) }

        schema envelope({ payment: ref('Payment'), order: ref('Order') })
        run_test! do |response|
          payment = order.payments.sole
          expect(payment).to have_attributes(status: 'pending', transaction_id: nil)
          expect(response.parsed_body.dig('data', 'payment', 'id')).to eq(payment.id)
          expect(order.reload.payment_status).to eq('unpaid')
        end
      end

      response '201', 'a retry after a failed attempt answers with the new payment' do
        before do
          order.payments.create!(payment_method: payment_method, amount: order.total_amount, status: 'failed')
          order.update!(payment_status: 'payment_failed')
        end

        schema envelope({ payment: ref('Payment'), order: ref('Order') })
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'payment', 'status')).to eq('completed')
          expect(order.reload.payment_status).to eq('paid')
        end
      end

      response '422', 'order is already paid (no double charge)' do
        before do
          Payments::PaymentProcessorService.process_payment(order: order, payment_method: payment_method)
        end

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order cannot be paid')
          expect(order.payments.count).to eq(1)
        end
      end

      response '422', 'payment method is inactive' do
        let(:payment_method) { create(:payment_method, :inactive) }

        schema ref('ErrorResponse')
        run_test! do
          expect(order.reload.status).to eq('pending')
        end
      end

      response '404', "another customer's order" do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test! do
          expect(order.payments).to be_empty
        end
      end
    end
  end

  path '/api/v1/payments/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Show a payment (owner of the order or admin)' do
      tags 'Payments'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let(:payment) do
        Payments::PaymentProcessorService.process_payment(order: order, payment_method: payment_method)
        order.payments.sole
      end
      let(:id) { payment.id }

      response '200', 'the customer who owns the order' do
        schema envelope({ payment: ref('Payment'), order: ref('Order'), payment_method: ref('PaymentMethod') })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'payment', 'id')).to eq(payment.id)
        end
      end

      response '200', 'an admin' do
        let(:current_user) { admin }

        schema envelope({ payment: ref('Payment'), order: ref('Order'), payment_method: ref('PaymentMethod') })
        run_test!
      end

      # 404, not 403, so the existence of another user's payment is not confirmed.
      response '404', "another customer's payment" do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Payment not found')
          expect(response.parsed_body).not_to have_key('data')
        end
      end

      response '404', 'unknown payment' do
        let(:id) { 0 }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    patch 'Update a payment (admin only)' do
      tags 'Payments'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { payment: { type: :object, properties: { status: { type: :string } } } }
      }

      let(:payment) do
        Payments::PaymentProcessorService.process_payment(order: order, payment_method: payment_method)
        order.payments.sole
      end
      let(:id) { payment.id }
      let(:body) { { payment: { status: 'refunded' } } }

      response '403', 'the customer who owns the order' do
        schema ref('ErrorResponse')
        run_test! do
          expect(payment.reload.status).to eq('completed')
        end
      end

      response '403', 'another customer: forbidden before the payment is looked up' do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Admin access required')
          expect(payment.reload.status).to eq('completed')
        end
      end
    end
  end

  path '/api/v1/payments/{id}/refund' do
    parameter name: :id, in: :path, type: :integer

    post 'Refund a payment (admin)' do
      tags 'Payments'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { refund: { type: :object, properties: { amount: { type: :number }, reason: { type: :string } } } }
      }

      let(:current_user) { admin }
      let(:payment) do
        Payments::PaymentProcessorService.process_payment(order: order, payment_method: payment_method)
        order.payments.sole
      end
      let(:id) { payment.id }
      let(:amount) { 100.00 }
      let(:body) { { refund: { amount: amount, reason: 'Damaged on arrival' } } }

      response '200', 'full refund' do
        schema envelope({ payment: ref('Payment') })

        run_test! do
          expect(payment.reload.status).to eq('refunded')
          expect(order.reload).to have_attributes(payment_status: 'refunded', status: 'pending')
        end
      end

      response '422', 'refund larger than the payment' do
        let(:amount) { 150.00 }

        schema ref('ErrorResponse')
        run_test! do
          expect(payment.reload.status).to eq('completed')
        end
      end

      response '403', 'customers cannot refund' do
        let(:current_user) { customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(payment.reload.status).to eq('completed')
        end
      end
    end
  end

  # Cash on delivery and bank transfers are paid outside the app: the payment waits as pending
  # until an admin confirms the money arrived.
  path '/api/v1/payments/{id}/confirm' do
    parameter name: :id, in: :path, type: :integer

    post 'Confirm an offline payment was received (admin)' do
      tags 'Payments'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      let(:current_user) { admin }
      let(:payment_method) { create(:payment_method, :cash_on_delivery) }
      let(:payment) do
        Payments::PaymentProcessorService.process_payment(order: order, payment_method: payment_method)
        order.payments.sole
      end
      let(:id) { payment.id }

      response '200', 'cash collected: payment completed and order paid' do
        schema envelope({ payment: ref('Payment') })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'payment', 'status')).to eq('completed')
          expect(payment.reload).to have_attributes(status: 'completed', processed_at: be_present)
          expect(order.reload).to have_attributes(payment_status: 'paid', status: 'pending')
        end
      end

      response '422', 'already confirmed' do
        before { post "/api/v1/payments/#{payment.id}/confirm", headers: auth_headers(admin) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Only pending offline payments can be confirmed')
        end
      end

      response '422', 'online payments are confirmed by the gateway' do
        let(:payment_method) { create(:payment_method, gateway_type: 'stripe') }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Only pending offline payments can be confirmed')
        end
      end

      response '422', 'the order was paid another way in the meantime' do
        before do
          payment
          Payments::PaymentProcessorService.process_payment(order: order, payment_method: create(:payment_method))
        end

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order cannot be paid')
          expect(payment.reload.status).to eq('pending')
          expect(order.payments.successful.count).to eq(1)
        end
      end

      response '403', 'customers cannot confirm their own payment' do
        let(:current_user) { customer }

        schema ref('ErrorResponse')
        run_test! do
          expect(payment.reload.status).to eq('pending')
          expect(order.reload.payment_status).to eq('unpaid')
        end
      end
    end
  end
end
