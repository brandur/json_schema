require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  it "expands references" do
    expand(data)
    # this was always a fully-defined property
    referenced = @schema.definitions.first
    # this used to be a $ref
    reference = @schema.properties.first

    assert_nil reference.reference
    assert_equal referenced.description, reference.description
    assert_equal referenced.id, reference.id
    assert_equal referenced.type, reference.type
    assert_equal referenced.uri, reference.uri
  end

  it "errors on a JSON Pointer that can't be resolved" do
    new_data = data.dup
    new_data["properties"]["app"] = {
      "$ref" => "#/definitions/nope"
    }
    e = assert_raises(RuntimeError) do
      expand(new_data)
    end
    assert_equal %{Couldn't resolve pointer "#/definitions/nope" in schema "/".},
      e.message
  end

  it "errors on a schema that can't be resolved" do
    new_data = data.dup
    new_data["properties"]["app"] = {
      "$ref" => "/schemata/user#/definitions/name"
    }
    e = assert_raises(RuntimeError) do
      expand(new_data)
    end
    assert_equal %{Couldn't resolve references: /schemata/user#/definitions/name.},
      e.message
  end

  it "errors on a circular reference" do
    new_data = data.dup
    new_data["definitions"]["app"] = {
      "$ref" => "#/properties/app"
    }
    e = assert_raises(RuntimeError) do
      expand(new_data)
    end
    assert_equal %{Couldn't resolve references: #/definitions/app.}, e.message
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
              "$ref" => "/schemata/app#/definitions/name"
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

  def expand(data)
    @schema = JsonSchema.parse(data)
    @expander = JsonSchema::ReferenceExpander.new(@schema)
    @expander.expand!
  end
end
