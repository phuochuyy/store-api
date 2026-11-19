require 'rails_helper'

# Contract tests: request specs written with the rswag DSL validate real responses against the
# hand-maintained component schemas in swagger/v1/components/schemas.yaml, so the published API
# docs cannot silently drift from the code.
#
# We do NOT run `rswag:specs:swaggerize`; swagger/v1/swagger.json is still built by
# `bin/rails swagger:merge`. The document key below is only used by rswag at test time.
module ContractSchemas
  COMPONENT_SCHEMAS = YAML.load_file(Rails.root.join('swagger/v1/components/schemas.yaml')).freeze

  module_function

  def ref(name)
    { '$ref' => "#/components/schemas/#{name}" }
  end

  # The `{ success:, data:, message: }` envelope produced by ApplicationController#render_success.
  def envelope(data_properties, required: data_properties.keys)
    {
      type: :object,
      required: %w[success data message],
      properties: {
        success: { type: :boolean, enum: [true] },
        message: { type: :string },
        data: { type: :object, required: required.map(&:to_s), properties: data_properties }
      }
    }
  end
end

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/contract.yaml' => {
      openapi: '3.0.1',
      info: { title: 'Store API contract tests', version: 'v1' },
      paths: {},
      components: {
        securitySchemes: { bearerAuth: { type: :http, scheme: :bearer, bearerFormat: 'JWT' } },
        schemas: ContractSchemas::COMPONENT_SCHEMAS
      }
    }
  }

  config.openapi_format = :yaml
end
