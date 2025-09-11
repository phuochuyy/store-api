require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s

  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Phone Store API V1',
        version: 'v1',
        description: 'API for managing a phone store with brands, categories, phones, and orders'
      },
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT
          }
        },
        schemas: {
          Brand: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'name', 'description' ]
          },
          Category: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'name', 'description' ]
          },
          Phone: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              price: { type: :number, format: :decimal },
              brand_id: { type: :integer },
              category_id: { type: :integer },
              stock_quantity: { type: :integer },
              image_url: { type: :string },
              specifications: { type: :string },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'name', 'description', 'price', 'brand_id', 'category_id', 'stock_quantity', 'image_url', 'specifications' ]
          },
          Order: {
            type: :object,
            properties: {
              id: { type: :integer },
              customer_name: { type: :string },
              customer_email: { type: :string },
              customer_phone: { type: :string },
              total_amount: { type: :number, format: :decimal },
              status: { type: :string, enum: [ 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled' ] },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'customer_name', 'customer_email', 'customer_phone', 'total_amount', 'status' ]
          },
          User: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              email: { type: :string },
              role: { type: :string, enum: [ 'admin', 'customer' ] },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: [ 'id', 'name', 'email', 'role' ]
          },
          Error: {
            type: :object,
            properties: {
              error: { type: :string }
            },
            required: [ 'error' ]
          }
        }
      }
    }
  }

  config.swagger_format = :yaml
end
