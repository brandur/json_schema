require "test_helper"

require "json_schema"

describe JsonSchema::SchemaError do
  it "can print a message with a pointer" do
    schema = JsonSchema::Schema.new
    schema.fragment = "#"

    e = JsonSchema::SchemaError.new(schema, "problem", nil)
    assert_equal "#: problem", e.to_s
  end

  it "can print a message without a pointer" do
    e = JsonSchema::SchemaError.new(nil, "problem", nil)
    assert_equal "problem", e.to_s
  end
end
