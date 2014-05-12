require "test_helper"

require "json_schema"

describe JsonSchema::Parser do
  before do
    @parser = JsonSchema::Parser.new
  end

  it "parses the basic attributes of a schema" do
    schema = @parser.parse!(schema_sample)
    assert_nil schema.id
    assert_equal "Example API", schema.title
    assert_equal "An example API.", schema.description
    assert_equal ["object"], schema.type
    assert_equal "/", schema.uri
  end

  it "parses subschemas" do
    schema = @parser.parse!(schema_sample).definitions["app"]
    assert_nil schema.reference
    assert_equal "App", schema.title
    assert_equal "An app.", schema.description
    assert_equal "schemata/app", schema.id
    assert_equal ["object"], schema.type
    assert_equal "/schemata/app", schema.uri
    refute_nil schema.parent
  end

  it "parses sub-subschemas" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["name"]
    assert_nil schema.reference
    assert_equal "unique name of app", schema.description
    assert_equal ["string"], schema.type
    assert_equal "/schemata/app", schema.uri
    refute_nil schema.parent
  end

  it "parses references" do
    schema = @parser.parse!(schema_sample).properties["app"]
    refute_nil schema.reference
    assert_nil schema.reference.uri
    assert_equal "#/definitions/app", schema.reference.pointer
    refute_nil schema.parent
  end

  it "parses array validations" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["flags"]
    assert_equal 1, schema.min_items
    assert_equal 10, schema.max_items
    assert_equal true, schema.unique_items
  end

  it "parses integer validations" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["id"]
    assert_equal 1, schema.min
    assert_equal false, schema.min_exclusive
    assert_equal 10000, schema.max
    assert_equal false, schema.max_exclusive
    assert_equal 1, schema.multiple_of
  end

  it "parses number validations" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["cost"]
    assert_equal 0.0, schema.min
    assert_equal false, schema.min_exclusive
    assert_equal 1000.0, schema.max
    assert_equal true, schema.max_exclusive
    assert_equal 0.01, schema.multiple_of
  end

  it "parses the basic set of object validations" do
    schema = @parser.parse!(schema_sample).definitions["app"]
    assert_equal false, schema.additional_properties
    assert_equal 10, schema.max_properties
    assert_equal 1, schema.min_properties
    assert_equal ["name"], schema.required
  end

  it "parses the dependencies object validation" do
    schema = @parser.parse!(schema_sample).definitions["app"]
    assert_equal ["ssl"], schema.dependencies["production"]
    assert_equal 20.0, schema.dependencies["ssl"].properties["cost"].min
  end

  it "parses the patternProperties object validation" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["config_vars"]
    property = schema.pattern_properties.first
    assert_equal /^\w+$/, property[0]
    assert_equal ["null", "string"], property[1].type
  end

  # couldn't think of any non-contrived examples to work with here
  it "parses the basic set of schema validations" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["contrived"]
    assert_equal 2, schema.all_of.count
    assert_equal 2, schema.one_of.count
    assert schema.not
  end

  it "parses the anyOf schema validation" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["identity"]
    assert_equal 2, schema.any_of.count
    assert_equal "/schemata/app#/definitions/id", schema.any_of[0].reference.to_s
    assert_equal "/schemata/app#/definitions/name", schema.any_of[1].reference.to_s
  end

  it "parses string validations" do
    schema = @parser.parse!(schema_sample).definitions["app"].definitions["name"]
    assert_equal 30, schema.max_length
    assert_equal 3, schema.min_length
    assert_equal /^[a-z][a-z0-9-]{3,30}$/, schema.pattern
  end

  it "errors on non-string ids" do
    local_schema_sample = schema_sample.dup
    local_schema_sample["id"] = 4
    e = assert_raises(RuntimeError) { @parser.parse!(local_schema_sample) }
    assert_equal %{At "/": Expected "id" to be of type "string"; value was: 4.},
      e.message
  end

  it "errors on non-string titles" do
    local_schema_sample = schema_sample.dup
    local_schema_sample["title"] = 4
    e = assert_raises(RuntimeError) { @parser.parse!(local_schema_sample) }
    assert_equal %{At "/": Expected "title" to be of type "string"; value was: 4.},
      e.message
  end

  it "errors on non-string descriptions" do
    local_schema_sample = schema_sample.dup
    local_schema_sample["description"] = 4
    e = assert_raises(RuntimeError) { @parser.parse!(local_schema_sample) }
    assert_equal %{At "/": Expected "description" to be of type "string"; value was: 4.},
      e.message
  end

  it "errors on non-array and non-string types" do
    local_schema_sample = schema_sample.dup
    local_schema_sample["type"] = 4
    e = assert_raises(RuntimeError) { @parser.parse!(local_schema_sample) }
    assert_equal %{At "/": Expected "type" to be of type "array/string"; value was: 4.},
      e.message
  end

  it "errors on unknown types" do
    local_schema_sample = schema_sample.dup
    local_schema_sample["type"] = ["float", "double"]
    e = assert_raises(RuntimeError) { @parser.parse!(local_schema_sample) }
    assert_equal %{At "/": Unknown types: double, float.},
      e.message
  end

  def schema_sample
    DataScaffold.schema_sample
  end
end
