require "test_helper"

require "json_schema"

describe JsonSchema::Schema do
  it "allows schema attribute access with #[]" do
    schema = JsonSchema::Schema.new
    schema.properties = { "foo" => nil }
    assert_equal({ "foo" => nil }, schema[:properties])
  end

  it "allows schema attribute access with #[] and overridden name" do
    schema = JsonSchema::Schema.new
    schema.additional_properties = { "foo" => nil }
    assert_equal({ "foo" => nil }, schema[:additionalProperties])
  end

  it "allows schema attribute access with #[] as string" do
    schema = JsonSchema::Schema.new
    schema.properties = { "foo" => nil }
    assert_equal({ "foo" => nil }, schema["properties"])
  end

  it "raises if attempting to access #[] with bad method" do
    schema = JsonSchema::Schema.new
    assert_raises NoMethodError do
      schema[:wat]
    end
  end

  it "raises if attempting to access #[] with non-schema attribute" do
    schema = JsonSchema::Schema.new
    assert_raises NoMethodError do
      schema[:expanded]
    end
  end

  it "updates type_parsed when type is changed" do
    schema = JsonSchema::Schema.new
    schema.type = ["integer"]
    assert_equal [Integer], schema.type_parsed

    schema.type = ["string"]
    assert_equal [String], schema.type_parsed
  end
end
