Rswag::Ui.configure do |c|
  # List the Swagger endpoints that you want to be documented through the
  # swagger-ui. The first parameter is the path (absolute or relative to the UI
  # host) to the corresponding endpoint and the second is a title that will be
  # displayed within the swagger-ui. A third parameter can be used to control
  # whether the endpoint is expanded by default. (default is 'false')
  #
  # Examples:
  #
  # c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'
  # c.swagger_endpoint '/api-docs/v1/swagger.json', 'API V1 Docs'
  # c.swagger_endpoint '/api-docs/v2/swagger.yaml', 'API V2 Docs'
  # c.swagger_endpoint '/api-docs/v2/swagger.json', 'API V2 Docs'
  # c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'Phone Store API V1'
  c.openapi_endpoint '/swagger/v1/swagger.json', 'Phone Store API V1'

  # Add Basic Auth in case your API is private
  # c.basic_auth_enabled = true
  # c.basic_auth_credentials 'username', 'password'
end
