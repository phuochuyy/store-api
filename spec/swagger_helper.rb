require 'rails_helper'
require 'rswag/specs'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.yaml'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Store API V1',
        version: 'v1',
        description: 'RESTful API for an e-commerce store built with Ruby on Rails',
        contact: {
          name: 'Store API Support',
          email: 'support@store-api.com'
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://api.store.com',
          description: 'Production server'
        }
      ],
      tags: [
        { name: 'Authentication', description: 'User authentication and email verification' },
        { name: 'Users', description: 'User management' },
        { name: 'Products', description: 'Product catalog management' },
        { name: 'Brands', description: 'Brand management' },
        { name: 'Categories', description: 'Category management' },
        { name: 'Shopping Cart', description: 'Shopping cart operations' },
        { name: 'Orders', description: 'Order management' },
        { name: 'Health', description: 'System health checks' }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT,
            description: 'JWT token obtained from login endpoint'
          }
        },
        schemas: {
          user: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'John Doe' },
              email: { type: :string, format: :email, example: 'john@example.com' },
              role: { type: :string, enum: %w[customer admin], example: 'customer' },
              email_verified_at: { type: :string, format: :'date-time', nullable: true },
              created_at: { type: :string, format: :'date-time' },
              updated_at: { type: :string, format: :'date-time' }
            }
          },
          product: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'iPhone 15 Pro' },
              description: { type: :string, example: 'Latest iPhone with advanced features' },
              price: { type: :number, format: :decimal, example: 999.99 },
              stock_quantity: { type: :integer, example: 50 },
              brand_id: { type: :integer, example: 1 },
              category_id: { type: :integer, example: 1 },
              image_url: { type: :string, format: :uri, nullable: true },
              created_at: { type: :string, format: :'date-time' },
              updated_at: { type: :string, format: :'date-time' }
            }
          },
          cart: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              user_id: { type: :integer, nullable: true, example: 1 },
              session_id: { type: :string, example: 'abc123def456' },
              status: { type: :string, enum: %w[active abandoned completed], example: 'active' },
              total_amount: { type: :number, format: :decimal, example: 299.99 },
              total_items: { type: :integer, example: 3 },
              created_at: { type: :string, format: :'date-time' },
              updated_at: { type: :string, format: :'date-time' }
            }
          },
          cart_item: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              cart_id: { type: :integer, example: 1 },
              product_id: { type: :integer, example: 1 },
              quantity: { type: :integer, example: 2 },
              unit_price: { type: :number, format: :decimal, example: 99.99 },
              total_price: { type: :number, format: :decimal, example: 199.98 },
              created_at: { type: :string, format: :'date-time' },
              updated_at: { type: :string, format: :'date-time' }
            }
          },
          error: {
            type: :object,
            properties: {
              success: { type: :boolean, example: false },
              error: { type: :string, example: 'Error message' },
              status: { type: :string, example: 'unauthorized' },
              errors: {
                type: :array,
                items: { type: :string },
                example: ["Email can't be blank", 'Password is too short']
              }
            }
          },
          success_response: {
            type: :object,
            properties: {
              success: { type: :boolean, example: true },
              data: { type: :object },
              message: { type: :string, example: 'Operation completed successfully' }
            }
          }
        },
        responses: {
          bad_request: {
            description: 'Bad request - Invalid parameters',
            content: {
              'application/json': {
                schema: {
                  allOf: [
                    { '$ref' => '#/components/schemas/error' },
                    {
                      type: :object,
                      properties: {
                        status: { example: 'bad_request' }
                      }
                    }
                  ]
                }
              }
            }
          },
          unauthorized: {
            description: 'Unauthorized - Invalid or missing authentication',
            content: {
              'application/json': {
                schema: {
                  allOf: [
                    { '$ref' => '#/components/schemas/error' },
                    {
                      type: :object,
                      properties: {
                        status: { example: 'unauthorized' }
                      }
                    }
                  ]
                }
              }
            }
          },
          not_found: {
            description: 'Resource not found',
            content: {
              'application/json': {
                schema: {
                  allOf: [
                    { '$ref' => '#/components/schemas/error' },
                    {
                      type: :object,
                      properties: {
                        status: { example: 'not_found' }
                      }
                    }
                  ]
                }
              }
            }
          },
          validation_error: {
            description: 'Validation error - Invalid input data',
            content: {
              'application/json': {
                schema: {
                  allOf: [
                    { '$ref' => '#/components/schemas/error' },
                    {
                      type: :object,
                      properties: {
                        status: { example: 'unprocessable_entity' },
                        errors: {
                          type: :array,
                          items: { type: :string },
                          example: ["Email can't be blank", 'Password is too short']
                        }
                      }
                    }
                  ]
                }
              }
            }
          }
        }
      },
      security: [
        {
          bearer_auth: []
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
