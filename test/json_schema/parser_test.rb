require "test_helper"

require "json_schema"

describe JsonSchema::Parser do
  before do
    @parser = JsonSchema::Parser.new
  end

  it "parses the basic attributes of a schema" do
    schema = @parser.parse(data)
    assert_nil schema.id
    assert_equal "Example API", schema.title
    assert_equal "An example API.", schema.description
    assert_equal ["object"], schema.type
  end

  it "parses subschemas" do
    schema = @parser.parse(data).definitions_children[0]
    assert_equal "App", schema.title
    assert_equal "An app.", schema.description
    assert_equal "schemata/app", schema.id
    assert_equal ["object"], schema.type
  end

  it "errors on non-string ids" do
    local_data = data.dup
    local_data["id"] = 4
    e = assert_raises(RuntimeError) { @parser.parse(local_data) }
    assert_equal %{Expected "id" to be of type "String"; value was: 4.},
      e.message
  end

  it "errors on non-string titles" do
    local_data = data.dup
    local_data["title"] = 4
    e = assert_raises(RuntimeError) { @parser.parse(local_data) }
    assert_equal %{Expected "title" to be of type "String"; value was: 4.},
      e.message
  end

  it "errors on non-string descriptions" do
    local_data = data.dup
    local_data["description"] = 4
    e = assert_raises(RuntimeError) { @parser.parse(local_data) }
    assert_equal %{Expected "description" to be of type "String"; value was: 4.},
      e.message
  end

  it "errors on non-array and non-string types" do
    local_data = data.dup
    local_data["type"] = 4
    e = assert_raises(RuntimeError) { @parser.parse(local_data) }
    assert_equal %{Expected "type" to be of type "Array/String"; value was: 4.},
      e.message
  end

  it "errors on unknown types" do
    local_data = data.dup
    local_data["type"] = ["float", "double"]
    e = assert_raises(RuntimeError) { @parser.parse(local_data) }
    assert_equal %{Unknown types: double, float.},
      e.message
  end

  def data
    {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "title" => "Example API",
      "description" => "An example API.",
      "type" => [
        "object"
      ],
      "definitions" => {
        "app" => {
          "$schema" => "http://json-schema.org/draft-04/hyper-schema",
          "title" => "App",
          "description" => "An app.",
          "id" => "schemata/app",
          "type" => [
            "object"
          ],
          "definitions" => {
            "name" => {
              "description" => "unique name of app",
              "example" => "name",
              "readOnly" => false,
              "type" => [
                "string"
              ]
            },
          },
          "properties" => {
            "app" => {
              "$ref" => "#/definitions/name"
            }
          }
        }
      },
      "properties" => {
        "app" => {
          "$ref" => "#/definitions/app"
        }
      },
      "links" => [
        {
          "href" => "http://example.com",
          "rel" => "self"
        }
      ]
    }
  end
end
