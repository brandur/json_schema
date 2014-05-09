require "test_helper"

require "json_schema"

describe JsonSchema::Parser do
  before do
    @parser = JsonSchema::Parser.new
  end

  it "parses the basic attributes of a schema" do
    schema = @parser.parse(data)
    assert_equal "Example API", schema.title
    assert_equal "An example API.", schema.description
    assert_nil schema.id
  end

  it "parses subschemas" do
    schema = @parser.parse(data).definitions_children[0]
    assert_equal "App", schema.title
    assert_equal "An app.", schema.description
    assert_equal "schemata/app", schema.id
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
