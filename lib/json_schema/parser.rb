require "json_reference"

module JsonSchema
  class Parser
    ALLOWED_TYPES = %w{any array boolean integer number null object string}
    BOOLEAN = [FalseClass, TrueClass]
    FRIENDLY_TYPES = {
      Array      => "array",
      FalseClass => "boolean",
      Float      => "float",
      Hash       => "object",
      Integer    => "integer",
      NilClass   => "null",
      String     => "string",
      TrueClass  => "boolean",
    }

    def parse(data, parent = nil)
      if ref = data["$ref"]
        schema = Schema.new
        schema.reference = JsonReference::Reference.new(ref)
      else
        schema = parse_schema(data, parent)
      end

      schema.parent = parent
      schema
    end

    private

    def validate_type!(data, types, field)
      friendly_types =
        types.map { |t| FRIENDLY_TYPES[t] || t }.sort.uniq.join("/")
      value = data[field]
      if !value.nil? && !types.any? { |t| value.is_a?(t) }
        raise %{Expected "#{field}" to be of type "#{friendly_types}"; value was: #{value.inspect}.}
      end
      value
    end

    def parse_definitions(data, schema)
      if data["definitions"]
        data["definitions"].each do |key, definition|
          subschema = parse(definition, schema)
          schema.definitions[key] = subschema
        end
      end
    end

    def parse_properties(data, schema)
      if data["properties"]
        data["properties"].each do |key, definition|
          subschema = parse(definition, schema)
          schema.properties[key] = subschema
        end
      end
    end

    def parse_schema(data, parent = nil)
      schema = Schema.new

      schema.data        = data

      schema.id          = validate_type!(data, [String], "id")
      schema.title       = validate_type!(data, [String], "title")
      schema.description = validate_type!(data, [String], "description")

      schema.type = validate_type!(data, [Array, String], "type")
      schema.type = [schema.type] if schema.type.is_a?(String)
      validate_known_type!(schema)

      # validation: array
      schema.max_items    = validate_type!(data, [Integer], "maxItems")
      schema.min_items    = validate_type!(data, [Integer], "minItems")
      schema.unique_items = validate_type!(data, BOOLEAN, "uniqueItems")

      # validation: number/integer
      schema.max           = validate_type!(data, [Float, Integer], "max")
      schema.max_exclusive = validate_type!(data, BOOLEAN, "maxExclusive")
      schema.min           = validate_type!(data, [Float, Integer], "min")
      schema.min_exclusive = validate_type!(data, BOOLEAN, "minExclusive")
      schema.multiple_of   = validate_type!(data, [Float, Integer], "multipleOf")

      # validation: object
      schema.additional_properties =
        validate_type!(data, BOOLEAN, "additionalProperties")
      schema.dependencies       = validate_type!(data, [Hash], "dependencies")
      schema.max_properties     = validate_type!(data, [Integer], "maxProperties")
      schema.min_properties     = validate_type!(data, [Integer], "minProperties")
      schema.pattern_properties = validate_type!(data, [Hash], "patternProperties")
      schema.required           = validate_type!(data, [Array], "required")

      # validation: schema
      schema.all_of        = validate_type!(data, [Array], "allOf")
      schema.any_of        = validate_type!(data, [Array], "anyOf")
      schema.one_of        = validate_type!(data, [Array], "oneOf")
      schema.not           = validate_type!(data, [Hash], "not")

      # validation: string
      schema.max_length = validate_type!(data, [Integer], "maxLength")
      schema.min_length = validate_type!(data, [Integer], "minLength")
      schema.pattern    = validate_type!(data, [String], "pattern")

      # build a URI to address this schema
      schema.uri = if parent
        build_uri(schema.id, parent.uri)
      else
        "/"
      end

      parse_definitions(data, schema)
      parse_properties(data, schema)

      # parse out the subschemas in the object validations category
      if schema.dependencies && schema.dependencies.is_a?(Hash)
        # leave the original data reference intact
        schema.dependencies = schema.dependencies.dup
        schema.dependencies.each do |k, s|
          # may be Array, String (simple dependencies), or Hash (schema
          # dependency)
          if s.is_a?(Hash)
            schema.dependencies[k] = parse(s, schema)
          elsif s.is_a?(String)
            # just normalize all simple dependencies to arrays
            schema.dependencies[k] = [s]
          end
        end
      end
      if schema.pattern_properties && schema.pattern_properties.is_a?(Hash)
        # leave the original data reference intact
        schema.pattern_properties = schema.pattern_properties.dup
        schema.pattern_properties.each do |k, s|
          schema.pattern_properties[k] = parse(s, schema)
        end
      end

      # parse out the subschemas in the schema validations category
      if schema.all_of && schema.all_of.is_a?(Array)
        schema.all_of = schema.all_of.map { |s| parse(s, schema) }
      end
      if schema.any_of && schema.any_of.is_a?(Array)
        schema.any_of = schema.any_of.map { |s| parse(s, schema) }
      end
      if schema.one_of && schema.one_of.is_a?(Array)
        schema.one_of = schema.one_of.map { |s| parse(s, schema) }
      end
      if schema.not && schema.not.is_a?(Hash)
        schema.not = parse(schema.not, schema)
      end

      schema
    end

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

    def validate_known_type!(schema)
      if schema.type
        if !(bad_types = schema.type - ALLOWED_TYPES).empty?
          raise %{Unknown types: #{bad_types.sort.join(", ")}.}
        end
      end
    end
  end
end
