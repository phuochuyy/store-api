require 'swagger_helper'

RSpec.describe 'Product variants API', type: :request do
  extend ContractSchemas

  def self.variant_envelope(data)
    {
      type: :object,
      required: %w[success data message],
      properties: { success: { type: :boolean, enum: [true] }, message: { type: :string }, data: data }
    }
  end

  def self.variant_body
    {
      type: :object,
      properties: {
        variant: {
          type: :object,
          properties: { name: { type: :string }, sku: { type: :string }, price: { type: :number },
                        stock_quantity: { type: :integer } }
        }
      }
    }
  end

  let(:customer) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:Authorization) { auth_headers(customer)['Authorization'] }
  let(:admin_authorization) { auth_headers(admin)['Authorization'] }
  let(:product) { create(:product) }
  let(:product_id) { product.id }

  path '/api/v1/products/{product_id}/variants' do
    parameter name: :product_id, in: :path, type: :integer

    get 'List the active variants of a product' do
      tags 'Product Variants'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      before do
        create(:product_variant, product: product, sku: 'ACTIVE-1')
        create(:product_variant, product: product, sku: 'INACTIVE-1', is_active: false)
      end

      response '200', 'active variants listed' do
        schema variant_envelope({ type: :array, items: ref('ProductVariant') })

        run_test! do |response|
          expect(response.parsed_body['data'].pluck('sku')).to eq(['ACTIVE-1'])
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end

      response '404', 'unknown product' do
        let(:product_id) { 0 }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    post 'Create a variant (admin only)' do
      tags 'Product Variants'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: variant_body

      let(:body) { { variant: { name: '256GB Blue', sku: 'IP15-256-BLUE', price: 1099.99, stock_quantity: 5 } } }

      response '201', 'variant created' do
        let(:Authorization) { admin_authorization }

        schema variant_envelope(ref('ProductVariant'))
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'price')).to eq('1099.99')
          expect(product.product_variants.sole).to have_attributes(sku: 'IP15-256-BLUE', price: 1099.99)
        end
      end

      response '403', 'customers cannot create variants' do
        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Access denied')
          expect(ProductVariant.count).to eq(0)
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test! do
          expect(ProductVariant.count).to eq(0)
        end
      end

      response '422', 'invalid variant' do
        let(:Authorization) { admin_authorization }
        let(:body) { { variant: { name: '', sku: '', price: -1, stock_quantity: 1 } } }

        schema ref('ErrorResponse')
        run_test! do
          expect(ProductVariant.count).to eq(0)
        end
      end
    end
  end

  path '/api/v1/products/{product_id}/variants/{id}' do
    parameter name: :product_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    let!(:variant) { create(:product_variant, product: product, price: 100.00) }
    let(:id) { variant.id }

    get 'Show a variant' do
      tags 'Product Variants'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'variant found' do
        schema variant_envelope(ref('ProductVariant'))
        run_test! do |response|
          expect(response.parsed_body.dig('data', 'id')).to eq(variant.id)
        end
      end

      response '404', 'variant of another product' do
        let(:id) { create(:product_variant).id }

        schema ref('ErrorResponse')
        run_test!
      end
    end

    patch 'Update a variant (admin only)' do
      tags 'Product Variants'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: variant_body

      let(:body) { { variant: { price: 89.50 } } }

      response '200', 'variant updated' do
        let(:Authorization) { admin_authorization }

        schema variant_envelope(ref('ProductVariant'))
        run_test! do
          expect(variant.reload.price).to eq(89.50)
        end
      end

      response '403', 'customers cannot update variants' do
        schema ref('ErrorResponse')
        run_test! do
          expect(variant.reload.price).to eq(100.00)
        end
      end
    end

    delete 'Delete a variant (admin only)' do
      tags 'Product Variants'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'variant deleted' do
        let(:Authorization) { admin_authorization }

        schema type: :object, required: %w[success message],
               properties: { success: { type: :boolean, enum: [true] }, message: { type: :string } }
        run_test! do
          expect(ProductVariant.exists?(variant.id)).to be false
        end
      end

      response '403', 'customers cannot delete variants' do
        schema ref('ErrorResponse')
        run_test! do
          expect(ProductVariant.exists?(variant.id)).to be true
        end
      end
    end
  end
end
