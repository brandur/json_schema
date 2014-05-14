require "test_helper"

require "json_schema"

describe JsonSchema::Parser do
  it "parses the basic attributes of a schema" do
    schema = parse
    assert_nil schema.id
    assert_equal "Example API", schema.title
    assert_equal "An example API.", schema.description
    assert_equal ["object"], schema.type
    assert_equal "/", schema.uri
  end

  it "parses subschemas" do
    schema = parse.definitions["app"]
    assert_nil schema.reference
    assert_equal "App", schema.title
    assert_equal "An app.", schema.description
    assert_equal "schemata/app", schema.id
    assert_equal ["object"], schema.type
    assert_equal "/schemata/app", schema.uri
    refute_nil schema.parent
  end

  it "parses sub-subschemas" do
    schema = parse.definitions["app"].definitions["name"]
    assert_nil schema.reference
    assert_equal "hello-world", schema.default
    assert_equal "unique name of app", schema.description
    assert_equal ["string"], schema.type
    assert_equal "/schemata/app", schema.uri
    refute_nil schema.parent
  end

  it "parses references" do
    schema = parse.properties["app"]
    refute_nil schema.reference
    assert_nil schema.reference.uri
    assert_equal "#/definitions/app", schema.reference.pointer
    refute_nil schema.parent
  end

  it "parses enum validation" do
    schema = parse.definitions["app"].definitions["visibility"]
    assert_equal ["private", "public"], schema.enum
  end

  it "parses array validations" do
    schema = parse.definitions["app"].definitions["flags"]
    assert_equal /^[a-z][a-z\-]*[a-z]$/, schema.items.pattern
    assert_equal 1, schema.min_items
    assert_equal 10, schema.max_items
    assert_equal true, schema.unique_items
  end

  it "parses array items tuple validation" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    schema = parse.definitions["app"].definitions["flags"]
    assert_equal ["bamboo", "cedar"], schema.items[0].enum
    assert_equal ["http", "https"], schema.items[1].enum
  end

  it "parses integer validations" do
    schema = parse.definitions["app"].definitions["id"]
    assert_equal 0, schema.min
    assert_equal true, schema.min_exclusive
    assert_equal 10000, schema.max
    assert_equal false, schema.max_exclusive
    assert_equal 1, schema.multiple_of
  end

  it "parses number validations" do
    schema = parse.definitions["app"].definitions["cost"]
    assert_equal 0.0, schema.min
    assert_equal false, schema.min_exclusive
    assert_equal 1000.0, schema.max
    assert_equal true, schema.max_exclusive
    assert_equal 0.01, schema.multiple_of
  end

  it "parses the basic set of object validations" do
    schema = parse.definitions["app"]
    assert_equal false, schema.additional_properties
    assert_equal 10, schema.max_properties
    assert_equal 1, schema.min_properties
    assert_equal ["name"], schema.required
  end

  it "parses the dependencies object validation" do
    schema = parse.definitions["app"]
    assert_equal ["ssl"], schema.dependencies["production"]
    assert_equal 20.0, schema.dependencies["ssl"].properties["cost"].min
  end

  it "parses the patternProperties object validation" do
    schema = parse.definitions["app"].definitions["config_vars"]
    property = schema.pattern_properties.first
    assert_equal /^\w+$/, property[0]
    assert_equal ["null", "string"], property[1].type
  end

  # couldn't think of any non-contrived examples to work with here
  it "parses the basic set of schema validations" do
    schema = parse.definitions["app"].definitions["contrived"]
    assert_equal 2, schema.all_of.count
    assert_equal 2, schema.one_of.count
    assert schema.not
  end

  it "parses the anyOf schema validation" do
    schema = parse.definitions["app"].definitions["identity"]
    assert_equal 2, schema.any_of.count
    assert_equal "/schemata/app#/definitions/id", schema.any_of[0].reference.to_s
    assert_equal "/schemata/app#/definitions/name", schema.any_of[1].reference.to_s
  end

  it "parses basic set of string validations" do
    schema = parse.definitions["app"].definitions["name"]
    assert_equal 30, schema.max_length
    assert_equal 3, schema.min_length
    assert_equal /^[a-z][a-z0-9-]{3,30}$/, schema.pattern
  end

  it "parses hypermedia links" do
    pointer("#/definitions/app").merge!(
      "links" => [
        "description" => "Create a new app.",
        "href" => "/apps",
        "method" => "POST",
        "rel" => "create",
        "schema" => {
          "properties" => {
            "name" => {
              "$ref" => "#/definitions/app/definitions/name"
            },
          }
        }
      ]
    )
    schema = parse.definitions["app"]
    link = schema.links[0]
    assert_equal schema, link.parent
    assert_equal "Create a new app.", link.description
    assert_equal "/apps", link.href
    assert_equal :post, link.method
    assert_equal "create", link.rel
    assert_equal "#/definitions/app/definitions/name",
      link.schema.properties["name"].reference.pointer
  end

  it "parses hypermedia media" do
    pointer("#/definitions/app/media").merge!(
      "binaryEncoding" => "base64",
      "type"           => "image/png"
    )
    schema = parse.definitions["app"]
    media = JsonSchema::Schema::Media.new
    assert_equal "base64", schema.media.binary_encoding
    assert_equal "image/png", schema.media.type
  end

  it "parses hypermedia pathStart" do
    pointer("#/definitions/app").merge!(
      "pathStart" => "/v2"
    )
    schema = parse.definitions["app"]
    assert_equal "/v2", schema.path_start
  end

  it "parses hypermedia readOnly" do
    pointer("#/definitions/app").merge!(
      "readOnly" => true
    )
    schema = parse.definitions["app"]
    assert_equal true, schema.read_only
  end

  it "errors on non-string ids" do
    schema_sample["id"] = 4
    refute parse
    assert_includes error_messages, %{Expected "id" to be of type "string"; value was: 4.}
  end

  it "errors on non-string titles" do
    schema_sample["title"] = 4
    refute parse
    assert_includes error_messages, %{Expected "title" to be of type "string"; value was: 4.}
  end

  it "errors on non-string descriptions" do
    schema_sample["description"] = 4
    refute parse
    assert_includes error_messages, %{Expected "description" to be of type "string"; value was: 4.}
  end

  it "errors on non-array and non-string types" do
    schema_sample["type"] = 4
    refute parse
    assert_includes error_messages, %{Expected "type" to be of type "array/string"; value was: 4.}
  end

  it "errors on unknown types" do
    schema_sample["type"] = ["float", "double"]
    refute parse
    assert_includes error_messages, %{Unknown types: double, float.}
  end

  def error_messages
    @parser.errors.map { |e| e.message }
  end

  def parse
    @parser = JsonSchema::Parser.new
    @parser.parse(schema_sample)
  end

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end
end
