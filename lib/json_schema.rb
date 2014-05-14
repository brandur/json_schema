require_relative "json_schema/parser"
require_relative "json_schema/reference_expander"
require_relative "json_schema/schema"
require_relative "json_schema/schema_error"
require_relative "json_schema/validator"

module JsonSchema
  def self.parse(data)
    parser = Parser.new
    if schema = parser.parse(data)
      valid, errors = schema.expand_references
      if valid
        [schema, nil]
      else
        [nil, errors]
      end
    else
      [nil, parser.errors]
    end
  end

  def self.parse!(data)
    schema = Parser.new.parse!(data)
    schema.expand_references!
    schema
  end
end
