require_relative "../json_reference"

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

      schema = parse_data(data, parent, "#")
      if @errors.count == 0
        schema
      else
        nil
      end
    end

    def parse!(data, parent = nil)
      schema = parse(data, parent)
      if !schema
        raise @errors.join(" ")
      end
      schema
    end

    private

    def build_uri(id, parent_uri)
      # kill any trailing slashes
      if id
        # may look like: http://json-schema.org/draft-04/hyper-schema#
        uri = URI.parse(id)
        # make sure there is no `#` suffix
        uri.fragment = nil
        # if id is defined as absolute, the schema's URI stays absolute
        if uri.absolute? || uri.path[0] == "/"
          uri.to_s.chomp("/")
        # otherwise build it according to the parent's URI
        elsif parent_uri
          # make sure we don't end up with duplicate slashes
          parent_uri = parent_uri.chomp("/")
          parent_uri + "/" + id
        else
          "/"
        end
      # if id is missing, it's defined as its parent schema's URI
      elsif parent_uri
        parent_uri
      else
        "/"
      end
    end

    def parse_additional_properties(schema)
      if schema.additional_properties
        # an object indicates a schema that will be used to parse any
        # properties not listed in `properties`
        if schema.additional_properties.is_a?(Hash)
          schema.additional_properties = parse_data(
            schema.additional_properties,
            schema,
            "additionalProperties"
          )
        end
        # otherwise, leave as boolean
      end
    end

    def parse_all_of(schema)
      if schema.all_of
        schema.all_of = schema.all_of.each_with_index.
          map { |s, i| parse_data(s, schema, "allOf/#{i}") }
      end
    end

    def parse_any_of(schema)
      if schema.any_of
        schema.any_of = schema.any_of.each_with_index.
          map { |s, i| parse_data(s, schema, "anyOf/#{i}") }
      end
    end

    def parse_one_of(schema)
      if schema.one_of
        schema.one_of = schema.one_of.each_with_index.
          map { |s, i| parse_data(s, schema, "oneOf/#{i}") }
      end
    end

    def parse_data(data, parent, fragment)
      if !data.is_a?(Hash)
        # it would be nice to make this message more specific/nicer (at best it
        # points to the wrong schema)
        message = %{Schema not found!}
        @errors << SchemaError.new(parent, message, :schema_not_found)
      elsif ref = data["$ref"]
        schema = Schema.new
        schema.fragment = fragment
        schema.parent = parent
        schema.reference = JsonReference::Reference.new(ref)
      else
        schema = parse_schema(data, parent, fragment)
      end

      schema
    end

    def parse_definitions(schema)
      if schema.definitions
        # leave the original data reference intact
        schema.definitions = schema.definitions.dup
        schema.definitions.each do |key, definition|
          subschema = parse_data(definition, schema, "definitions/#{key}")
          schema.definitions[key] = subschema
        end
      end
    end

    def parse_dependencies(schema)
      if schema.dependencies
        # leave the original data reference intact
        schema.dependencies = schema.dependencies.dup
        schema.dependencies.each do |k, s|
          # may be Array, String (simple dependencies), or Hash (schema
          # dependency)
          if s.is_a?(Hash)
            schema.dependencies[k] = parse_data(s, schema, "dependencies")
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
          schema.items = schema.items.each_with_index.
            map { |s, i| parse_data(s, schema, "items/#{i}") }
        # list validation: a single schema
        else
          schema.items = parse_data(schema.items, schema, "items")
        end
      end
    end

    def parse_links(schema)
      if schema.links
        schema.links = schema.links.each_with_index.map { |l, i|
          link             = Schema::Link.new
          link.parent      = schema

          link.description = l["description"]
          link.enc_type    = l["encType"]
          link.href        = l["href"]
          link.method      = l["method"] ? l["method"].downcase.to_sym : nil
          link.rel         = l["rel"]
          link.title       = l["title"]
          link.media_type  = l["mediaType"]

          if l["schema"]
            link.schema = parse_data(l["schema"], schema, "links/#{i}/schema")
          end

          if l["targetSchema"]
            link.target_schema =
              parse_data(l["targetSchema"], schema, "links/#{i}/targetSchema")
          end

          link
        }
      end
    end

    def parse_media(schema)
      if data = schema.media
        schema.media = Schema::Media.new
        schema.media.binary_encoding = data["binaryEncoding"]
        schema.media.type            = data["type"]
      end
    end

    def parse_not(schema)
      if schema.not
        schema.not = parse_data(schema.not, schema, "not")
      end
    end

    def parse_pattern_properties(schema)
      if schema.pattern_properties
        # leave the original data reference intact
        properties = schema.pattern_properties.dup
        properties = properties.map do |k, s|
          [Regexp.new(k), parse_data(s, schema, "patternProperties/#{k}")]
        end
        schema.pattern_properties = Hash[*properties.flatten]
      end
    end

    def parse_properties(schema)
      # leave the original data reference intact
      schema.properties = schema.properties.dup
      if schema.properties && schema.properties.is_a?(Hash)
        schema.properties.each do |key, definition|
          subschema = parse_data(definition, schema, "properties/#{key}")
          schema.properties[key] = subschema
        end
      end
    end

    def parse_schema(data, parent, fragment)
      schema = Schema.new
      schema.fragment = fragment
      schema.parent   = parent

      schema.data        = data
      schema.id          = validate_type(schema, [String], "id")

      # any parsed schema is automatically expanded
      schema.expanded    = true

      # build URI early so we can reference it in errors
      schema.uri         = build_uri(schema.id, parent ? parent.uri : nil)

      schema.title       = validate_type(schema, [String], "title")
      schema.description = validate_type(schema, [String], "description")
      schema.default     = schema.data["default"]

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
        validate_type(schema, BOOLEAN + [Hash], "additionalProperties")
      schema.dependencies       = validate_type(schema, [Hash], "dependencies") || {}
      schema.max_properties     = validate_type(schema, [Integer], "maxProperties")
      schema.min_properties     = validate_type(schema, [Integer], "minProperties")
      schema.pattern_properties = validate_type(schema, [Hash], "patternProperties") || {}
      schema.properties         = validate_type(schema, [Hash], "properties") || {}
      schema.required           = validate_type(schema, [Array], "required")
      schema.strict_properties  = validate_type(schema, BOOLEAN, "strictProperties")

      # validation: string
      schema.format     = validate_type(schema, [String], "format")
      schema.max_length = validate_type(schema, [Integer], "maxLength")
      schema.min_length = validate_type(schema, [Integer], "minLength")
      schema.pattern    = validate_type(schema, [String], "pattern")
      schema.pattern    = Regexp.new(schema.pattern) if schema.pattern

      # hyperschema
      schema.links      = validate_type(schema, [Array], "links")
      schema.media      = validate_type(schema, [Hash], "media")
      schema.path_start = validate_type(schema, [String], "pathStart")
      schema.read_only  = validate_type(schema, BOOLEAN, "readOnly")

      parse_additional_properties(schema)
      parse_all_of(schema)
      parse_any_of(schema)
      parse_one_of(schema)
      parse_definitions(schema)
      parse_dependencies(schema)
      parse_items(schema)
      parse_links(schema)
      parse_media(schema)
      parse_not(schema)
      parse_pattern_properties(schema)
      parse_properties(schema)

      schema
    end

    def validate_known_type!(schema)
      if schema.type
        if !(bad_types = schema.type - ALLOWED_TYPES).empty?
          message = %{Unknown types: #{bad_types.sort.join(", ")}.}
          @errors << SchemaError.new(schema, message, :unknown_type)
        end
      end
    end

    def validate_type(schema, types, field)
      friendly_types =
        types.map { |t| FRIENDLY_TYPES[t] || t }.sort.uniq.join("/")
      value = schema.data[field]
      if !value.nil? && !types.any? { |t| value.is_a?(t) }
        message = %{#{value.inspect} is not a valid "#{field}", must be a #{friendly_types}.}
        @errors << SchemaError.new(schema, message, :invalid_type)
        nil
      else
        value
      end
    end
  end
end
