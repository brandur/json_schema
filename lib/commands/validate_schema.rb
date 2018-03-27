require "json"
require "yaml"
require_relative "../json_schema"

module Commands
  class ValidateSchema
    attr_accessor :detect
    attr_accessor :fail_fast
    attr_accessor :extra_schemas

    attr_accessor :errors
    attr_accessor :messages

    def initialize
      @detect = false
      @fail_fast = false
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
        if !(data = read_file(data_file))
          return false
        end

        if detect
          if !(schema_uri = data["$schema"])
            @errors = ["#{data_file}: No $schema tag for detection."]
            return false
          end

          if !(schema = @store.lookup_schema(schema_uri))
            @errors = ["#{data_file}: Unknown $schema, try specifying one with -s."]
            return false
          end
        end

        valid, errors = schema.validate(data, fail_fast: fail_fast)

        if valid
          @messages += ["#{data_file} is valid."]
        else
          @errors = map_schema_errors(data_file, errors)
        end
      end

      @errors.empty?
    end

    private

    def initialize_store
      @store = JsonSchema::DocumentStore.new
      extra_schemas.each do |extra_schema|
        if !(extra_schema = parse(extra_schema))
          return false
        end
        @store.add_schema(extra_schema)
      end
      true
    end

    # Builds a JSON Reference + message like "/path/to/file#/path/to/data".
    def map_schema_errors(file, errors)
      errors.map { |m| "#{file}#{m}" }
    end

    def parse(file)
      if !(schema_data = read_file(file))
        return nil
      end

      parser = JsonSchema::Parser.new
      if !(schema = parser.parse(schema_data))
        @errors = map_schema_errors(file, parser.errors)
        return nil
      end

      expander = JsonSchema::ReferenceExpander.new
      if !expander.expand(schema, store: @store)
        @errors = map_schema_errors(file, expander.errors)
        return nil
      end

      schema
    end

    def read_file(file)
      contents = File.read(file)

      # Perform an empty check because boath YAML and JSON's load will return
      # `nil` in the case of an empty file, which will otherwise produce
      # confusing results.
      if contents.empty?
        @errors = ["#{file}: File is empty."]
        nil
      else
        if File.extname(file) == ".yaml"
          YAML.load(contents)
        else
          JSON.load(contents)
        end
      end
    rescue Errno::ENOENT
      @errors = ["#{file}: No such file or directory."]
      nil
    rescue JSON::ParserError
      # Ruby's parsing exceptions aren't too helpful, just point user to
      # a better tool
      @errors = ["#{file}: Invalid JSON. Try to validate using `jsonlint`."]
      nil
    rescue Psych::SyntaxError
      @errors = ["#{file}: Invalid YAML."]
      nil
    end
  end
end
