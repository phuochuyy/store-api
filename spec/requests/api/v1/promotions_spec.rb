require 'swagger_helper'

RSpec.describe 'Promotions API (applying to an order)', type: :request do
  extend ContractSchemas

  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:current_user) { customer }
  let(:Authorization) { auth_headers(current_user)['Authorization'] }

  let(:order) { create(:order, :with_items, user: customer) }
  let(:promotion) do
    Promotion.create!(name: 'Free shipping', promotion_type: 'shipping_discount', conditions: {},
                      benefits: { free_shipping: true }, usage_limit: 10)
  end

  path '/api/v1/promotions/{id}/apply' do
    parameter name: :id, in: :path, type: :integer

    post 'Apply a promotion to an order (owner of the order or admin)' do
      tags 'Promotions'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: { type: :object, properties: { order_id: { type: :integer } } }

      let(:id) { promotion.id }
      let(:body) { { order_id: order.id } }

      response '200', 'the customer who owns the order' do
        run_test! do
          expect(promotion.reload.used_count).to eq(1)
        end
      end

      response '200', 'an admin, on any order' do
        let(:current_user) { admin }

        run_test! do
          expect(promotion.reload.used_count).to eq(1)
        end
      end

      # 404, not 403, so the existence of another user's order is not confirmed.
      response '404', "another customer's order" do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order not found')
          expect(promotion.reload.used_count).to eq(0)
        end
      end

      response '404', 'unknown promotion' do
        let(:id) { 0 }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Promotion not found')
        end
      end

      response '422', 'the order is already delivered and paid' do
        let(:order) { create(:order, :with_items, :delivered, user: customer, payment_status: 'paid') }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq(Order::DISCOUNT_LOCKED_ERROR)
          expect(promotion.reload.used_count).to eq(0)
        end
      end
    end
  end

  path '/api/v1/promotions/applicable' do
    get 'Promotions that apply to an order (owner of the order or admin)' do
      tags 'Promotions'
      security [{ bearerAuth: [] }]
      produces 'application/json'
      parameter name: :order_id, in: :query, type: :integer

      let(:order_id) { order.id }

      before { promotion }

      response '200', 'the customer who owns the order' do
        run_test! do |response|
          names = response.parsed_body.dig('data', 'promotions').map { |entry| entry.dig('promotion', 'name') }
          expect(names).to include('Free shipping')
        end
      end

      response '404', "another customer's order" do
        let(:current_user) { create(:user) }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Order not found')
        end
      end
    end
  end
end
