require_relative "json_schema/parser"
require_relative "json_schema/reference_expander"
require_relative "json_schema/schema"
require_relative "json_schema/schema_error"

module JsonSchema
  def self.parse(data)
    Parser.new.parse(data).expand_references!
  end
end
