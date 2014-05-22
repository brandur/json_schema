require_relative "../json_schema"

module Commands
  class ValidateSchema
    attr_accessor :detect
    attr_accessor :extra_schemas

    attr_accessor :errors
    attr_accessor :messages

    def initialize
      @detect = false
      @extra_schemas = []

      @errors = []
      @messages = []
    end

    def run(argv)
      return false if !initialize_store

      if !detect
        return false if !(schema_file = argv.shift)
        return false if !(schema = parse(schema_file))
      end

      # if there are no remaining files in arguments, also a problem
      return false if argv.count < 1

      argv.each do |data_file|
        return false if !check_file(data_file)
        data = JSON.parse(File.read(data_file))

        if detect
          if !(schema_uri = data["$schema"])
            @errors = ["#{data_file}: No $schema tag for detection."]
            return false
          end

          if !(schema = @store.lookup_uri(schema_uri))
            @errors = ["#{data_file}: Unknown $schema, try specifying one with -s."]
            return false
          end
        end

        valid, errors = schema.validate(data)

        if valid
          @messages += ["#{data_file} is valid."]
        else
          @errors = ["#{data_file}: Invalid."] +
            map_schema_errors(data_file, errors)
        end
      end

      @errors.empty?
    end

    private

    def check_file(file)
      if !File.exists?(file)
        @errors = ["#{file}: No such file or directory."]
        false
      else
        true
      end
    end

    def initialize_store
      @store = JsonSchema::DocumentStore.new
      extra_schemas.each do |extra_schema|
        if !(extra_schema = parse(extra_schema))
          return false
        end
        @store.add_uri_reference(extra_schema.uri, extra_schema)
      end
      true
    end

    # Builds a JSON Reference + message like "/path/to/file#/path/to/data".
    def map_schema_errors(file, errors)
      errors.map { |e|
        if e.is_a?(JsonSchema::ValidationError)
          "#{file}#{e.pointer}: failed #{e.schema.pointer}: #{e.message}"
        else
          "#{file}#{e.schema.pointer}: #{e.message}"
        end
      }
    end

    def parse(file)
      return nil if !check_file(file)

      parser = JsonSchema::Parser.new
      if !(schema = parser.parse(JSON.parse(File.read(file))))
        @errors = ["#{file}: Schema is invalid."] + 
          map_schema_errors(file, parser.errors)
        return nil
      end

      expander = JsonSchema::ReferenceExpander.new
      if !expander.expand(schema, store: @store)
        @errors = ["#{file}: Could not expand schema references."] +
          map_schema_errors(file, expander.errors)
        return nil
      end

      schema
    end
  end
end
