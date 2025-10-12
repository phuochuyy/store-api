namespace :swagger do
  desc "Merge all Swagger files into a single swagger.json"
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
      file_name = File.basename(file_path, '.yaml')
      content = YAML.load_file(file_path)
      
      # Merge all endpoints from this file
      content.each do |endpoint_name, endpoint_def|
        paths[endpoint_name] = endpoint_def
      end
    end
    
    # Load schemas
    schemas_file = Rails.root.join('swagger/v1/components/schemas.yaml')
    schemas = YAML.load_file(schemas_file)
    
    # Build complete swagger spec
    complete_spec = {
      'openapi' => main_content['openapi'],
      'info' => main_content['info'],
      'servers' => main_content['servers'],
      'tags' => main_content['tags'],
      'paths' => {},
      'components' => {
        'securitySchemes' => main_content['components']['securitySchemes'],
        'schemas' => schemas
      }
    }
    
    # Add all paths
    main_content['paths'].each do |path, ref|
      if ref.is_a?(Hash) && ref['$ref']
        # Extract endpoint name from $ref
        endpoint_name = ref['$ref'].split('#/').last
        if paths[endpoint_name]
          complete_spec['paths'][path] = paths[endpoint_name]
        end
      end
    end
    
    # Write complete swagger.json
    output_file = Rails.root.join('swagger/v1/swagger.json')
    File.write(output_file, JSON.pretty_generate(complete_spec))
    
    puts "✅ Merged Swagger files into #{output_file}"
    puts "📊 Total endpoints: #{complete_spec['paths'].keys.length}"
  end
end
