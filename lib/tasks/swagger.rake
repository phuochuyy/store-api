namespace :swagger do
  desc 'Generate Swagger documentation from code'
  task generate: :environment do
    puts '🚀 Generating Swagger documentation...'

    # This task can be extended to auto-generate documentation from code
    # For now, we'll validate the existing YAML file

    begin
      require 'yaml'

      # Load and validate the swagger YAML
      swagger_file = Rails.root.join('swagger/v1/swagger.yaml')
      swagger_content = YAML.load_file(swagger_file)

      puts '✅ Swagger YAML file is valid'
      puts "📊 Found #{swagger_content['paths']&.keys&.count || 0} endpoints"
      puts "📋 Found #{swagger_content['components']['schemas']&.keys&.count || 0} schemas"
      puts "🏷️  Found #{swagger_content['tags']&.count || 0} tags"

      # Basic validation
      required_sections = %w[openapi info paths components]
      missing_sections = required_sections - swagger_content.keys

      if missing_sections.any?
        puts "❌ Missing required sections: #{missing_sections.join(', ')}"
        exit 1
      end

      puts '✅ All required sections present'
      puts '🎉 Swagger documentation is ready!'
    rescue Psych::SyntaxError => e
      puts "❌ YAML syntax error: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc 'Validate Swagger documentation'
  task validate: :environment do
    puts '🔍 Validating Swagger documentation...'

    begin
      require 'yaml'

      swagger_file = Rails.root.join('swagger/v1/swagger.yaml')
      swagger_content = YAML.load_file(swagger_file)

      # Validate OpenAPI version
      unless swagger_content['openapi']&.start_with?('3.')
        puts "❌ Invalid OpenAPI version: #{swagger_content['openapi']}"
        exit 1
      end

      # Validate required info fields
      info = swagger_content['info']
      required_info_fields = %w[title version description]
      missing_info_fields = required_info_fields - info.keys

      if missing_info_fields.any?
        puts "❌ Missing required info fields: #{missing_info_fields.join(', ')}"
        exit 1
      end

      # Validate paths
      paths = swagger_content['paths']
      if paths.nil? || paths.empty?
        puts '❌ No paths defined'
        exit 1
      end

      # Validate components
      components = swagger_content['components']
      if components.nil?
        puts '❌ No components defined'
        exit 1
      end

      # Validate schemas
      schemas = components['schemas']
      if schemas.nil? || schemas.empty?
        puts '❌ No schemas defined'
        exit 1
      end

      # Validate security schemes
      security_schemes = components['securitySchemes']
      if security_schemes.nil? || security_schemes.empty?
        puts '❌ No security schemes defined'
        exit 1
      end

      puts "✅ OpenAPI version: #{swagger_content['openapi']}"
      puts "✅ API title: #{info['title']}"
      puts "✅ API version: #{info['version']}"
      puts "✅ Endpoints: #{paths.keys.count}"
      puts "✅ Schemas: #{schemas.keys.count}"
      puts "✅ Security schemes: #{security_schemes.keys.count}"
      puts '🎉 Swagger documentation is valid!'
    rescue Psych::SyntaxError => e
      puts "❌ YAML syntax error: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "❌ Validation error: #{e.message}"
      exit 1
    end
  end

  desc 'Export Swagger documentation to JSON'
  task export_json: :environment do
    puts '📤 Exporting Swagger documentation to JSON...'

    begin
      require 'yaml'
      require 'json'

      swagger_file = Rails.root.join('swagger/v1/swagger.yaml')
      swagger_content = YAML.load_file(swagger_file)

      json_file = Rails.root.join('swagger/v1/swagger.json')
      File.write(json_file, JSON.pretty_generate(swagger_content))

      puts "✅ Exported to: #{json_file}"
      puts "📊 File size: #{File.size(json_file)} bytes"
    rescue StandardError => e
      puts "❌ Export error: #{e.message}"
      exit 1
    end
  end

  desc 'Show Swagger documentation statistics'
  task stats: :environment do
    puts '📊 Swagger Documentation Statistics'
    puts '=' * 50

    begin
      require 'yaml'

      swagger_file = Rails.root.join('swagger/v1/swagger.yaml')
      swagger_content = YAML.load_file(swagger_file)

      # Basic stats
      puts "📄 File: #{swagger_file}"
      puts "📏 File size: #{File.size(swagger_file)} bytes"
      puts "📅 Last modified: #{File.mtime(swagger_file)}"
      puts ''

      # API info
      info = swagger_content['info']
      puts '🏷️  API Information:'
      puts "   Title: #{info['title']}"
      puts "   Version: #{info['version']}"
      puts "   Description length: #{info['description']&.length || 0} characters"
      puts ''

      # Endpoints
      paths = swagger_content['paths']
      puts "🔗 Endpoints (#{paths.keys.count}):"
      paths.each do |path, methods|
        puts "   #{path}: #{methods.keys.join(', ').upcase}"
      end
      puts ''

      # Schemas
      schemas = swagger_content['components']['schemas']
      puts "📋 Schemas (#{schemas.keys.count}):"
      schemas.keys.each do |schema|
        puts "   - #{schema}"
      end
      puts ''

      # Tags
      tags = swagger_content['tags']
      puts "🏷️  Tags (#{tags.count}):"
      tags.each do |tag|
        puts "   - #{tag['name']}: #{tag['description']}"
      end
      puts ''

      # Security
      security_schemes = swagger_content['components']['securitySchemes']
      puts "🔐 Security Schemes (#{security_schemes.keys.count}):"
      security_schemes.each do |name, scheme|
        puts "   - #{name}: #{scheme['type']} (#{scheme['scheme']})"
      end
      puts ''

      # Response codes
      response_codes = Set.new
      paths.each do |_path, methods|
        methods.each do |_method, details|
          details['responses']&.each do |code, _|
            response_codes.add(code)
          end
        end
      end

      puts "📊 Response Codes (#{response_codes.count}):"
      response_codes.sort.each do |code|
        puts "   - #{code}"
      end
    rescue StandardError => e
      puts "❌ Error generating statistics: #{e.message}"
      exit 1
    end
  end

  desc 'Clean up generated Swagger files'
  task clean: :environment do
    puts '🧹 Cleaning up generated Swagger files...'

    files_to_clean = [
      Rails.root.join('swagger/v1/swagger.json'),
      Rails.public_path.join('swagger-ui'),
      Rails.root.join('tmp/swagger')
    ]

    files_to_clean.each do |file|
      if File.exist?(file)
        if File.directory?(file)
          FileUtils.rm_rf(file)
          puts "🗑️  Removed directory: #{file}"
        else
          File.delete(file)
          puts "🗑️  Removed file: #{file}"
        end
      end
    end

    puts '✅ Cleanup completed'
  end
end

# Default task
task swagger: 'swagger:validate'
