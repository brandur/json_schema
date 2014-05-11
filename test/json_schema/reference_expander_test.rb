require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  before do
    @schema = JsonSchema.parse(data)
    @expander = JsonSchema::ReferenceExpander.new(@schema)
  end

  it "expands references" do
    @expander.expand!
    # this was always a fully-defined property
    referenced = @schema.definitions_children.first
    # this used to be a $ref
    reference = @schema.properties_children.first

    assert_nil reference.reference
    assert_equal referenced.description, reference.description
    assert_equal referenced.id, reference.id
    assert_equal referenced.type, reference.type
    assert_equal referenced.uri, reference.uri
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
end
