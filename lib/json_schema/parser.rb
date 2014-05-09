require "json_reference"

module JsonSchema
  class Parser
    ALLOWED_TYPES = %w{any array boolean integer number null object string}

    def parse(data)
      if ref = data["$ref"]
        schema = Schema.new
        schema.reference = JsonReference::Reference.new(ref)
        schema
      else
        parse_schema(data)
      end
    end

    private

    def check_type!(types, field, value)
      if !value.nil? && !types.any? { |t| value.is_a?(t) }
        raise %{Expected "#{field}" to be of type "#{types.join("/")}"; value was: #{value.inspect}.}
      end
    end

    def parse_definitions(data, schema)
      if data["definitions"]
        data["definitions"].each do |key, definition|
          subschema = parse(definition)
          subschema.parent = schema
          if !subschema.reference
            subschema.uri = build_uri(subschema.id, schema.uri)
          end
          schema.definitions_children << subschema
        end
      end
    end

    def parse_properties(data, schema)
      if data["properties"]
        data["properties"].each do |key, definition|
          subschema = parse(definition)
          subschema.parent = schema
          if !subschema.reference
            subschema.uri = build_uri(subschema.id, schema.uri)
          end
          schema.properties_children << subschema
        end
      end
    end

    def parse_schema(data)
      schema = Schema.new

      schema.data        = data

      schema.id          = data["id"]
      schema.title       = data["title"]
      schema.description = data["description"]

      schema.type = if data["type"].is_a?(Array)
        data["type"]
      elsif data["type"].is_a?(String)
        [data["type"]]
      else
        ["any"]
      end

      validate(data, schema)
      parse_definitions(data, schema)
      parse_properties(data, schema)

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

    def validate(data, schema)
      check_type!([String], "id", schema.id)
      check_type!([String], "title", schema.title)
      check_type!([String], "description", schema.description)

      check_type!([Array, String], "type", data["type"])

      if !(bad_types = schema.type - ALLOWED_TYPES).empty?
        raise %{Unknown types: #{bad_types.sort.join(", ")}.}
      end
    end
  end
end
