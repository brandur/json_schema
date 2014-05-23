require_relative "json_schema/document_store"
require_relative "json_schema/parser"
require_relative "json_schema/reference_expander"
require_relative "json_schema/schema"
require_relative "json_schema/schema_error"
require_relative "json_schema/validator"

module JsonSchema
  def self.parse(data)
    parser = Parser.new
    if schema = parser.parse(data)
      [schema, nil]
    else
      [nil, parser.errors]
    end
  end

  def self.parse!(data)
    Parser.new.parse!(data)
  end
end
