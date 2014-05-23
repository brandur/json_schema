require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  it "expands references" do
    expand
    assert_equal [], errors

    # this was always a fully-defined property
    referenced = @schema.definitions["app"]
    # this used to be a $ref
    reference = @schema.properties["app"]

    assert_equal "#/definitions/app", reference.reference.pointer
    assert_equal referenced.description, reference.description
    assert_equal referenced.id, reference.id
    assert_equal referenced.type, reference.type
    assert_equal referenced.uri, reference.uri
  end

  it "takes a document store" do
    store = JsonSchema::DocumentStore.new
    expand(store: store)
    assert store.lookup_uri("/")
  end

  it "will expand anyOf" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 3, schema.any_of[0].min_length
    assert_equal 5, schema.any_of[1].min_length
  end

  it "will expand allOf" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 30, schema.all_of[0].max_length
    assert_equal 3, schema.all_of[1].min_length
  end

  it "will expand dependencies" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].dependencies["ssl"].properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will expand items list schema" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "$ref" => "#/definitions/app/definitions/name"
      }
    )
    expand
    assert_equal [], errors
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
    expand
    assert_equal [], errors
    schema0 = @schema.properties["app"].properties["flags"].items[0]
    schema1 = @schema.properties["app"].properties["flags"].items[0]
    assert_equal ["string"], schema0.type
    assert_equal ["string"], schema1.type
  end

  it "will expand oneOf" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal /^(foo|aaa)$/, schema.one_of[0].pattern
    assert_equal /^(foo|zzz)$/, schema.one_of[1].pattern
  end

  it "will expand not" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal /^$/, schema.not.pattern
  end

  it "will expand additionalProperties" do
    pointer("#").merge!(
      "additionalProperties" => { "$ref" => "#" }
    )
    expand
    assert_equal [], errors
    schema = @schema.additional_properties
    assert_equal ["object"], schema.type
  end

  it "will expand patternProperties" do
    expand
    assert_equal [], errors
    # value ([1]) of the #first tuple in hash
    schema = @schema.properties["app"].definitions["roles"].
      pattern_properties.first[1]
    assert_equal ["string"], schema.type
  end

  it "will expand hyperschema link schemas" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].links[0].schema.properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will expand hyperschema link targetSchemas" do
    expand
    assert_equal [], errors
    schema = @schema.properties["app"].links[0].target_schema.properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will perform multiple passes to resolve all references" do
    pointer("#/properties").merge!(
      "app0" => { "$ref" => "#/properties/app1" },
      "app1" => { "$ref" => "#/properties/app2" },
      "app2" => { "$ref" => "#/definitions/app" },
    )
    expand
    assert_equal [], errors
    schema = @schema.properties["app0"]
    assert_equal ["object"], schema.type
  end

  it "will resolve circular dependencies" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#" }
    )
    expand
    assert_equal [], errors
    schema = @schema.properties["app"]
    assert_equal ["object"], schema.type
  end

  it "builds appropriate JSON Pointers for expanded references" do
    expand
    assert_equal [], errors

    # the *referenced* schema should still have a proper pointer
    schema = @schema.definitions["app"].definitions["name"]
    assert_equal "#/definitions/app/definitions/name", schema.pointer

    # the *reference* schema should have expanded a pointer
    schema = @schema.properties["app"].properties["name"]
    assert_equal "#/properties/app/properties/name", schema.pointer
  end

  # clones are special in that they retain their original pointer despite where
  # they've been nested
  it "builds appropriate JSON Pointers for circular dependencies" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#" }
    )
    expand

    # the first self reference has the standard pointer as expected
    schema = @schema.properties["app"]
    assert_equal "#/properties/app", schema.pointer

    # but diving deeper results in the same pointer again
    schema = schema.properties["app"]
    assert_equal "#/properties/app", schema.pointer
  end

  it "errors on a JSON Pointer that can't be resolved" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#/definitions/nope" }
    )
    refute expand
    assert_includes errors,
      %{Couldn't resolve pointer "#/definitions/nope".}
    assert_includes errors,
      %{Couldn't resolve references: #/definitions/nope.}
  end

  it "errors on a URI that can't be resolved" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "/schemata/user#/definitions/name" }
    )
    refute expand
    assert_includes errors,
      %{Couldn't resolve references: /schemata/user#/definitions/name.}
    assert_includes errors, %{Couldn't resolve URI: /schemata/user.}
  end

  it "errors on a reference cycle" do
    pointer("#/properties").merge!(
      "app0" => { "$ref" => "#/properties/app2" },
      "app1" => { "$ref" => "#/properties/app0" },
      "app2" => { "$ref" => "#/properties/app1" },
    )
    refute expand
    properties = "#/properties/app0, #/properties/app1, #/properties/app2"
    assert_includes errors, %{Reference cycle detected: #{properties}.}
    assert_includes errors, %{Couldn't resolve references: #{properties}.}
  end

  def errors
    @expander.errors.map { |e| e.message }
  end

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end

  def expand(options = {})
    @schema = JsonSchema::Parser.new.parse!(schema_sample)
    @expander = JsonSchema::ReferenceExpander.new
    @expander.expand(@schema, options)
  end
end
