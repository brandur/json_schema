require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  it "expands references" do
    expand(data)
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

  it "will perform multiple passes to resolve all references" do
    new_data = data.dup
    new_data["properties"] = {
      "app" => {
        "$ref" => "#/properties/my-app"
      },
      "my-app" => {
        "$ref" => "#/definitions/app"
      }
    }
    expand(new_data)
  end

  it "errors on a JSON Pointer that can't be resolved" do
    new_data = data.dup
    new_data["properties"]["app"] = {
      "$ref" => "#/definitions/nope"
    }
    e = assert_raises(RuntimeError) do
      expand(new_data)
    end
    assert_equal %{/: Couldn't resolve pointer "#/definitions/nope".},
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
    assert_equal %{/: Couldn't resolve references: /schemata/user#/definitions/name.},
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
    assert_equal %{/: Couldn't resolve references: #/definitions/app.}, e.message
  end

  def data
    DataScaffold.sample
  end

  def expand(data)
    @schema = JsonSchema::Parser.new.parse!(data)
    @expander = JsonSchema::ReferenceExpander.new(@schema)
    @expander.expand!
  end
end
