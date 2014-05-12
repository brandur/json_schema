require "json_reference"

module JsonSchema
  class Parser
    ALLOWED_TYPES = %w{any array boolean integer number null object string}
    BOOLEAN = [FalseClass, TrueClass]

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
      value = data[field]
      if !value.nil? && !types.any? { |t| value.is_a?(t) }
        raise %{Expected "#{field}" to be of type "#{types.join("/")}"; value was: #{value.inspect}.}
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
      if schema.type.is_a?(String)
        schema.type = [schema.type]
      elsif schema.type.nil?
        schema.type = ["any"]
      end
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

      # parse out the subschemas in the schema validations category
      schema.all_of = schema.all_of.map { |s| parse(s, schema) } if schema.all_of
      schema.any_of = schema.any_of.map { |s| parse(s, schema) } if schema.any_of
      schema.one_of = schema.one_of.map { |s| parse(s, schema) } if schema.one_of
      schema.not    = parse(schema.not, schema) if schema.not

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
      if !(bad_types = schema.type - ALLOWED_TYPES).empty?
        raise %{Unknown types: #{bad_types.sort.join(", ")}.}
      end
    end
  end
end
