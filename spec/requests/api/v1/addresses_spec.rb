require 'swagger_helper'

RSpec.describe 'Address validation API', type: :request do
  extend ContractSchemas

  let(:Authorization) { auth_headers(create(:user))['Authorization'] }

  path '/api/v1/addresses/validate' do
    post 'Validate and normalize an address' do
      tags 'Addresses'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: { type: :object, properties: { address: { type: :object } } }

      let(:address) { { street: ' 1 Main St ', city: 'springfield', postal_code: '12345', country_code: 'US' } }
      let(:body) { { address: address } }

      response '200', 'valid address, normalized' do
        schema envelope({ valid: { type: :boolean }, normalized_address: { type: :object },
                          errors: { type: :array }, suggestions: { type: :array } })

        run_test! do |response|
          data = response.parsed_body['data']
          expect(data['valid']).to be true
          expect(data['normalized_address']).to include('street' => '1 Main St', 'city' => 'Springfield',
                                                        'country_code' => 'US', 'country' => 'United States')
        end
      end

      response '200', 'invalid address' do
        let(:address) { { street: '1 Main St', country_code: 'usa' } }

        schema envelope({ valid: { type: :boolean }, errors: { type: :array, items: { type: :string } } })

        run_test! do |response|
          data = response.parsed_body['data']
          expect(response.parsed_body['message']).to eq('Address validation failed')
          expect(data['valid']).to be false
          expect(data['errors']).to include('City is required', a_string_starting_with('Country code must be'))
        end
      end

      response '400', 'missing address' do
        let(:body) { {} }

        schema ref('ErrorResponse')
        run_test!
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end

  path '/api/v1/addresses/autocomplete' do
    get 'Suggest addresses for a partial query' do
      tags 'Addresses'
      security [{ bearerAuth: [] }]
      produces 'application/json'
      parameter name: :query, in: :query, type: :string, required: false

      let(:query) { 'Main St' }

      response '200', 'suggestions (empty without an external provider)' do
        schema envelope({ suggestions: { type: :array } })

        run_test! do |response|
          expect(response.parsed_body.dig('data', 'suggestions')).to eq([])
        end
      end

      response '400', 'missing query' do
        let(:query) { '' }

        schema ref('ErrorResponse')
        run_test! do |response|
          expect(response.parsed_body['message']).to eq('Query is required')
        end
      end

      response '401', 'missing token' do
        let(:Authorization) { nil }

        schema ref('ErrorResponse')
        run_test!
      end
    end
  end
end
