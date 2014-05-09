module JsonSchema
  def self.parse
  end

  class Parser
    ALLOWED_TYPES = %w{any array boolean integer number null object string}

    def parse(data)
      schema = Schema.new

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
          schema.definitions_children << subschema
        end
      end
    end

    def parse_properties(data, schema)
      if data["properties"]
        data["properties"].each do |key, definition|
          subschema = parse(definition)
          subschema.parent = schema
          schema.properties_children << subschema
        end
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

  class Schema
    # basic descriptors
    attr_accessor :id
    attr_accessor :title
    attr_accessor :description

    # Types assigned to this schema. Always an array/union type no matter what
    # was defined in the original schema (defaults to `["any"]`).
    attr_accessor :type

    # parent and children schemas
    attr_accessor :parent
    attr_accessor :definitions_children
    attr_accessor :properties_children

    def initialize
      @type = []

      @definitions_children = []
      @properties_children = []
    end
  end
end
