namespace :swagger do
  desc 'Merge all Swagger files into a single swagger.json'
  task merge: :environment do
    require 'yaml'
    require 'json'

    # Load main swagger file
    main_file = Rails.root.join('swagger/v1/swagger.yaml')
    main_content = YAML.load_file(main_file)

    # Load all path files
    paths_dir = Rails.root.join('swagger/v1/paths')
    paths = {}

    Dir.glob(paths_dir.join('*.yaml')).each do |file_path|
      File.basename(file_path, '.yaml')
      content = YAML.load_file(file_path)

      # Merge all endpoints from this file
      content.each do |endpoint_name, endpoint_def|
        paths[endpoint_name] = endpoint_def
      end
    end

    # Load schemas
    schemas_file = Rails.root.join('swagger/v1/components/schemas.yaml')
    schemas = YAML.load_file(schemas_file)

    # Process schema references in main_content
    processed_schemas = {}
    if main_content['components'] && main_content['components']['schemas']
      main_content['components']['schemas'].each do |schema_name, schema_ref|
        if schema_ref.is_a?(Hash) && schema_ref['$ref']
          ref_path = schema_ref['$ref']
          if ref_path.start_with?('./components/schemas.yaml#/')
            schema_key = ref_path.split('#/').last
            processed_schemas[schema_name] = schemas[schema_key] if schemas[schema_key]
          end
        else
          # Resolve $ref references within the schema
          resolved_schema = resolve_refs(schema_ref, schemas)
          processed_schemas[schema_name] = resolved_schema
        end

        # Also resolve references in schemas that have $ref
        next unless schema_ref.is_a?(Hash) && schema_ref['$ref']

        ref_path = schema_ref['$ref']
        next unless ref_path.start_with?('./components/schemas.yaml#/')

        schema_key = ref_path.split('#/').last
        if schemas[schema_key]
          resolved_schema = resolve_refs(schemas[schema_key], schemas)
          processed_schemas[schema_name] = resolved_schema
        end
      end
    end

    # Build complete swagger spec
    complete_spec = {
      'openapi' => main_content['openapi'],
      'info' => main_content['info'],
      'servers' => main_content['servers'],
      'tags' => main_content['tags'],
      'paths' => {},
      'components' => {
        'securitySchemes' => main_content['components']['securitySchemes'],
        'schemas' => processed_schemas
      }
    }

    # Add all paths
    main_content['paths'].each do |path, ref|
      next unless ref.is_a?(Hash) && ref['$ref']

      # Extract file path and endpoint name from $ref
      ref_path = ref['$ref']
      next unless ref_path.start_with?('./paths/') && ref_path.include?('#/')

      file_part, endpoint_part = ref_path.split('#/')
      file_name = file_part.gsub('./paths/', '').gsub('.yaml', '')
      endpoint_name = endpoint_part

      # Load the specific file and get the endpoint
      file_path = Rails.root.join("swagger/v1/paths/#{file_name}.yaml")
      next unless File.exist?(file_path)

      file_content = YAML.load_file(file_path)
      endpoint_content = file_content[endpoint_name]
      next unless endpoint_content

      # Resolve $ref references in the endpoint content
      resolved_content = resolve_refs(endpoint_content, processed_schemas)
      complete_spec['paths'][path] = resolved_content
    end

    # Write complete swagger.json
    output_file = Rails.root.join('swagger/v1/swagger.json')
    File.write(output_file, JSON.pretty_generate(complete_spec))

    puts "Merged Swagger files into #{output_file}"
    puts "Total endpoints: #{complete_spec['paths'].keys.length}"
  end

  private

  def resolve_refs(obj, schemas)
    case obj
    when Hash
      if obj.key?('$ref')
        ref_path = obj['$ref']
        if ref_path.start_with?('../components/schemas.yaml#/')
          schema_name = ref_path.split('#/').last
          return { '$ref' => "#/components/schemas/#{schema_name}" } if schemas[schema_name]
        elsif ref_path.start_with?('#/') && !ref_path.start_with?('#/components/schemas/')
          # Handle references like "#/User" -> "#/components/schemas/User"
          schema_name = ref_path.gsub('#/', '')
          return { '$ref' => "#/components/schemas/#{schema_name}" } if schemas[schema_name]
        end
        obj
      else
        resolved = {}
        obj.each do |key, value|
          resolved[key] = resolve_refs(value, schemas)
        end
        resolved
      end
    when Array
      obj.map { |item| resolve_refs(item, schemas) }
    else
      obj
    end
  end
end
