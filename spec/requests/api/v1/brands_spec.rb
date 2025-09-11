require 'swagger_helper'

RSpec.describe 'Brands API', type: :request do
  path '/api/v1/brands' do
    get 'Retrieves all brands' do
      tags 'Brands'
      produces 'application/json'

      response '200', 'brands found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'name', 'description' ]
          }

        run_test!
      end
    end

    post 'Creates a brand' do
      tags 'Brands'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :brand, in: :body, schema: {
        type: :object,
        properties: {
          brand: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string }
            },
            required: [ 'name', 'description' ]
          }
        }
      }

      response '201', 'brand created' do
        let(:brand) { { brand: { name: 'Test Brand', description: 'Test Description' } } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:brand) { { brand: { name: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/brands/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves a brand' do
      tags 'Brands'
      produces 'application/json'

      response '200', 'brand found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            name: { type: :string },
            description: { type: :string },
            created_at: { type: :string, format: :datetime },
            updated_at: { type: :string, format: :datetime }
          },
          required: [ 'id', 'name', 'description' ]

        let(:id) { Brand.create!(name: 'Test Brand', description: 'Test Description').id }
        run_test!
      end

      response '404', 'brand not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    put 'Updates a brand' do
      tags 'Brands'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :brand, in: :body, schema: {
        type: :object,
        properties: {
          brand: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string }
            }
          }
        }
      }

      response '200', 'brand updated' do
        let(:id) { Brand.create!(name: 'Test Brand', description: 'Test Description').id }
        let(:brand) { { brand: { name: 'Updated Brand' } } }
        run_test!
      end

      response '404', 'brand not found' do
        let(:id) { 'invalid' }
        let(:brand) { { brand: { name: 'Updated Brand' } } }
        run_test!
      end
    end

    delete 'Deletes a brand' do
      tags 'Brands'

      response '204', 'brand deleted' do
        let(:id) { Brand.create!(name: 'Test Brand', description: 'Test Description').id }
        run_test!
      end

      response '404', 'brand not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end
end
