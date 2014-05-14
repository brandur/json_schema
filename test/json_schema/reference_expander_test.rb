require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  it "expands references" do
    assert expand

    # this was always a fully-defined property
    referenced = @schema.definitions["app"]
    # this used to be a $ref
    reference = @schema.properties["app"]

    assert_nil reference.reference
    assert_equal referenced.description, reference.description
    assert_equal referenced.id, reference.id
    assert_equal referenced.type, reference.type
    assert_equal referenced.uri, reference.uri
  end

  it "will expand anyOf" do
    assert expand
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 3, schema.any_of[0].min_length
    assert_equal 5, schema.any_of[1].min_length
  end

  it "will expand allOf" do
    assert expand
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 30, schema.all_of[0].max_length
    assert_equal 3, schema.all_of[1].min_length
  end

  it "will expand dependencies" do
    assert expand
    schema = @schema.properties["app"].dependencies["ssl"].properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will expand items list schema" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "$ref" => "#/definitions/app/definitions/name"
      }
    )
    assert expand
    schema = @schema.properties["app"].properties["flags"].items
    assert_equal ["string"], schema.type
  end

  it "will expand items tuple schema" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "$ref" => "#/definitions/app/definitions/name" },
        { "$ref" => "#/definitions/app/definitions/owner" }
      ]
    )
    assert expand
    schema0 = @schema.properties["app"].properties["flags"].items[0]
    schema1 = @schema.properties["app"].properties["flags"].items[0]
    assert_equal ["string"], schema0.type
    assert_equal ["string"], schema1.type
  end

  it "will expand oneOf" do
    assert expand
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal /^(foo|aaa)$/, schema.one_of[0].pattern
    assert_equal /^(foo|zzz)$/, schema.one_of[1].pattern
  end

  it "will expand not" do
    assert expand
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal /^$/, schema.not.pattern
  end

  it "will expand patternProperties" do
    assert expand
    # value ([1]) of the #first tuple in hash
    schema = @schema.properties["app"].definitions["roles"].
      pattern_properties.first[1]
    assert_equal ["string"], schema.type
  end

  it "will expand hyperschema link schemas" do
    assert expand
    schema = @schema.properties["app"].links[0].schema.properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will perform multiple passes to resolve all references" do
    schema_sample["properties"] = {
      "app" => {
        "$ref" => "#/properties/my-app"
      },
      "my-app" => {
        "$ref" => "#/definitions/app"
      }
    }
    assert expand
  end

  it "errors on a JSON Pointer that can't be resolved" do
    schema_sample["properties"]["app"] = {
      "$ref" => "#/definitions/nope"
    }
    e = assert_raises(RuntimeError) { expand }
    assert_equal %{At "/": Couldn't resolve pointer "#/definitions/nope".},
      e.message
  end

  it "errors on a schema that can't be resolved" do
    schema_sample["properties"]["app"] = {
      "$ref" => "/schemata/user#/definitions/name"
    }
    e = assert_raises(RuntimeError) { expand }
    assert_equal %{At "/": Couldn't resolve references (possible circular dependency): /schemata/user#/definitions/name.},
      e.message
  end

  it "errors on a circular reference" do
    schema_sample["definitions"]["app"] = {
      "$ref" => "#/properties/app"
    }
    e = assert_raises(RuntimeError) { expand }
    assert_equal %{At "/": Couldn't resolve references (possible circular dependency): #/definitions/app.}, e.message
  end

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end

  def expand
    @schema = JsonSchema::Parser.new.parse!(schema_sample)
    @expander = JsonSchema::ReferenceExpander.new
    @expander.expand!(@schema)
  end
end
