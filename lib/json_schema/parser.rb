require "json_reference"

module JsonSchema
  class Parser
    ALLOWED_TYPES = %w{any array boolean integer number null object string}
    BOOLEAN = [FalseClass, TrueClass]
    FRIENDLY_TYPES = {
      Array      => "array",
      FalseClass => "boolean",
      Float      => "number",
      Hash       => "object",
      Integer    => "integer",
      NilClass   => "null",
      String     => "string",
      TrueClass  => "boolean",
    }

    attr_accessor :errors

    # Basic parsing of a schema. May return a malformed schema! (Use `#parse!`
    # to raise errors instead).
    def parse(data, parent = nil)
      # while #parse_data is recursed into for many schemas over the same
      # object, the @errors array is an instance-wide accumulator
      @errors = []

      parse_data(data, parent)
    end

    def parse!(data, parent = nil)
      schema = parse(data, parent)
      if @errors.count > 0
        raise SchemaError.aggregate(@errors)
      end
      schema
    end

    private

    def build_uri(id, parent_uri)
      # kill any trailing slashes
      if id
        id = id.chomp("/")
      end

      # if id is missing, it's defined as its parent schema's URI
      if id.nil?
        parent_uri
      # if id is defined as absolute, the schema's URI stays absolute
      elsif id[0] == "/"
        id
      # otherwise build it according to the parent's URI
      else
        # make sure we don't end up with duplicate slashes
        parent_uri = parent_uri.chomp("/")
        parent_uri + "/" + id
      end
    end

    def parse_all_of(schema)
      if schema.all_of && schema.all_of.is_a?(Array)
        schema.all_of = schema.all_of.map { |s| parse_data(s, schema) }
      end
    end

    def parse_any_of(schema)
      if schema.any_of && schema.any_of.is_a?(Array)
        schema.any_of = schema.any_of.map { |s| parse_data(s, schema) }
      end
    end

    def parse_one_of(schema)
      if schema.one_of && schema.one_of.is_a?(Array)
        schema.one_of = schema.one_of.map { |s| parse_data(s, schema) }
      end
    end

    def parse_data(data, parent = nil)
      if ref = data["$ref"]
        schema = Schema.new
        schema.reference = JsonReference::Reference.new(ref)
      else
        schema = parse_schema(data, parent)
      end

      schema.parent = parent
      schema
    end

    def parse_definitions(schema)
      if schema.definitions && schema.definitions.is_a?(Hash)
        # leave the original data reference intact
        schema.definitions = schema.definitions.dup
        schema.definitions.each do |key, definition|
          subschema = parse_data(definition, schema)
          schema.definitions[key] = subschema
        end
      end
    end

    def parse_dependencies(schema)
      if schema.dependencies && schema.dependencies.is_a?(Hash)
        # leave the original data reference intact
        schema.dependencies = schema.dependencies.dup
        schema.dependencies.each do |k, s|
          # may be Array, String (simple dependencies), or Hash (schema
          # dependency)
          if s.is_a?(Hash)
            schema.dependencies[k] = parse_data(s, schema)
          elsif s.is_a?(String)
            # just normalize all simple dependencies to arrays
            schema.dependencies[k] = [s]
          end
        end
      end
    end

    def parse_items(schema)
      if schema.items
        # tuple validation: an array of schemas
        if schema.items.is_a?(Array)
          schema.items = schema.items.map { |s| parse_data(s, schema) }
        # list validation: a single schema
        else
          schema.items = parse_data(schema.items, schema)
        end
      end
    end

    def parse_links(schema)
      if schema.links
        schema.links = schema.links.map { |l|
          link             = Link.new
          link.description = l["description"]
          link.href        = l["href"]
          link.method      = l["method"] ? l["method"].downcase.to_sym : nil
          link.rel         = l["rel"]
          link.title       = l["title"]

          if l["schema"]
            link.schema = parse_data(l["schema"], schema)
          end

          link
        }
      end
    end

    def parse_not(schema)
      if schema.not && schema.not.is_a?(Hash)
        schema.not = parse_data(schema.not, schema)
      end
    end

    def parse_pattern_properties(schema)
      if schema.pattern_properties && schema.pattern_properties.is_a?(Hash)
        # leave the original data reference intact
        properties = schema.pattern_properties.dup
        properties = properties.map do |k, s|
          [Regexp.new(k), parse_data(s, schema)]
        end
        schema.pattern_properties = Hash[*properties.flatten]
      end
    end

    def parse_properties(schema)
      # leave the original data reference intact
      schema.properties = schema.properties.dup
      if schema.properties && schema.properties.is_a?(Hash)
        schema.properties.each do |key, definition|
          subschema = parse_data(definition, schema)
          schema.properties[key] = subschema
        end
      end
    end

    def parse_schema(data, parent = nil)
      schema = Schema.new

      schema.data        = data
      schema.id          = validate_type(schema, [String], "id")

      # build URI early so we can reference it in errors
      schema.uri = parent ?  build_uri(schema.id, parent.uri) : "/"

      schema.title       = validate_type(schema, [String], "title")
      schema.description = validate_type(schema, [String], "description")
      schema.default     = validate_type(schema, [String], "default")

      # validation: any
      schema.all_of        = validate_type(schema, [Array], "allOf") || []
      schema.any_of        = validate_type(schema, [Array], "anyOf") || []
      schema.definitions   = validate_type(schema, [Hash], "definitions") || {}
      schema.enum          = validate_type(schema, [Array], "enum")
      schema.one_of        = validate_type(schema, [Array], "oneOf") || []
      schema.not           = validate_type(schema, [Hash], "not")
      schema.type          = validate_type(schema, [Array, String], "type")
      schema.type          = [schema.type] if schema.type.is_a?(String)
      validate_known_type!(schema)

      # validation: array
      schema.additional_items = validate_type(schema, BOOLEAN, "additionalItems")
      schema.items            = validate_type(schema, [Array, Hash], "items")
      schema.max_items        = validate_type(schema, [Integer], "maxItems")
      schema.min_items        = validate_type(schema, [Integer], "minItems")
      schema.unique_items     = validate_type(schema, BOOLEAN, "uniqueItems")

      # validation: number/integer
      schema.max           = validate_type(schema, [Float, Integer], "maximum")
      schema.max_exclusive = validate_type(schema, BOOLEAN, "exclusiveMaximum")
      schema.min           = validate_type(schema, [Float, Integer], "minimum")
      schema.min_exclusive = validate_type(schema, BOOLEAN, "exclusiveMinimum")
      schema.multiple_of   = validate_type(schema, [Float, Integer], "multipleOf")

      # validation: object
      schema.additional_properties =
        validate_type(schema, BOOLEAN, "additionalProperties")
      schema.dependencies       = validate_type(schema, [Hash], "dependencies") || {}
      schema.max_properties     = validate_type(schema, [Integer], "maxProperties")
      schema.min_properties     = validate_type(schema, [Integer], "minProperties")
      schema.pattern_properties = validate_type(schema, [Hash], "patternProperties") || {}
      schema.properties         = validate_type(schema, [Hash], "properties") || {}
      schema.required           = validate_type(schema, [Array], "required")

      # validation: string
      schema.format     = validate_type(schema, [String], "format")
      schema.max_length = validate_type(schema, [Integer], "maxLength")
      schema.min_length = validate_type(schema, [Integer], "minLength")
      schema.pattern    = validate_type(schema, [String], "pattern")
      schema.pattern    = Regexp.new(schema.pattern) if schema.pattern

      # hyperschema
      schema.links = validate_type(schema, [Array], "links")

      parse_all_of(schema)
      parse_any_of(schema)
      parse_one_of(schema)
      parse_definitions(schema)
      parse_dependencies(schema)
      parse_items(schema)
      parse_links(schema)
      parse_not(schema)
      parse_pattern_properties(schema)
      parse_properties(schema)

      schema
    end

    def validate_known_type!(schema)
      if schema.type
        if !(bad_types = schema.type - ALLOWED_TYPES).empty?
          message = %{Unknown types: #{bad_types.sort.join(", ")}.}
          @errors << SchemaError.new(schema, message)
        end
      end
    end

    def validate_type(schema, types, field)
      friendly_types =
        types.map { |t| FRIENDLY_TYPES[t] || t }.sort.uniq.join("/")
      value = schema.data[field]
      if !value.nil? && !types.any? { |t| value.is_a?(t) }
        message = %{Expected "#{field}" to be of type "#{friendly_types}"; value was: #{value.inspect}.}
        @errors << SchemaError.new(schema, message)
        nil
      else
        value
      end
    end
  end
end
