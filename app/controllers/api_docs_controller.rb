class ApiDocsController < ApplicationController
  def index
    render html: swagger_ui_html.html_safe
  end

  def swagger_yaml
    send_file Rails.root.join('swagger/v1/swagger.yaml'), type: 'text/yaml', disposition: 'inline'
  end

  def swagger_json
    send_file Rails.root.join('swagger/v1/swagger.json'), type: 'application/json', disposition: 'inline'
  end

  private

  def swagger_ui_html
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Store API Documentation</title>
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
        <style>
          html {
            box-sizing: border-box;
            overflow: -moz-scrollbars-vertical;
            overflow-y: scroll;
          }
          *, *:before, *:after {
            box-sizing: inherit;
          }
          body {
            margin:0;
            background: #fafafa;
          }
        </style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
        <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
        <script>
          window.onload = function() {
            const ui = SwaggerUIBundle({
              url: '/swagger/v1/swagger.yaml',
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ],
              layout: "StandaloneLayout",
              validatorUrl: null,
              tryItOutEnabled: true,
              requestInterceptor: function(request) {
                // Add CORS headers if needed
                request.headers['Content-Type'] = 'application/json';
                return request;
              },
              responseInterceptor: function(response) {
                return response;
              }
            });
          };
        </script>
      </body>
      </html>
    HTML
  end
end
