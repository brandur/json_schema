module JsonSchema
  def self.parse
  end

  class Parser
    def parse(data)
      schema = Schema.new

      schema.id          = data["id"]
      schema.title       = data["title"]
      schema.description = data["description"]

      check_type!(String, "id", schema.id)
      check_type!(String, "title", schema.title)
      check_type!(String, "description", schema.description)

      parse_definitions(data, schema)
      parse_properties(data, schema)

      schema
    end

    private

    def check_type!(type, field, value)
      if !value.nil? && !value.is_a?(type)
        raise %{Expected "#{field}" to be of type "#{type}"; value was: #{value.inspect}.}
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
  end

  class Schema
    # basic descriptors
    attr_accessor :id
    attr_accessor :title
    attr_accessor :description

    # types assigned to this schema
    attr_accessor :types

    # parent and children schemas
    attr_accessor :parent
    attr_accessor :definitions_children
    attr_accessor :properties_children

    def initialize
      @types = []

      @definitions_children = []
      @properties_children = []
    end
  end
end
