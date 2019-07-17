require "test_helper"

require "json_schema"

describe JsonSchema::ReferenceExpander do
  it "expands references" do
    expand
    assert_equal [], error_messages

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
    assert_equal store, @expander.store
  end

  it "will expand anyOf" do
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 3, schema.any_of[0].min_length
    assert_equal 5, schema.any_of[1].min_length
  end

  it "will expand allOf" do
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal 30, schema.all_of[0].max_length
    assert_equal 3, schema.all_of[1].min_length
  end

  it "will expand dependencies" do
    expand
    assert_equal [], error_messages
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
    assert_equal [], error_messages
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
    assert_equal [], error_messages
    schema0 = @schema.properties["app"].properties["flags"].items[0]
    schema1 = @schema.properties["app"].properties["flags"].items[0]
    assert_equal ["string"], schema0.type
    assert_equal ["string"], schema1.type
  end

  it "will expand oneOf" do
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal(/^(foo|aaa)$/, schema.one_of[0].pattern)
    assert_equal(/^(foo|zzz)$/, schema.one_of[1].pattern)
  end

  it "will expand not" do
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"].definitions["contrived_plus"]
    assert_equal(/^$/, schema.not.pattern)
  end

  it "will expand additionalProperties" do
    pointer("#").merge!(
      "additionalProperties" => { "$ref" => "#" }
    )
    expand
    assert_equal [], error_messages
    schema = @schema.additional_properties
    assert_equal ["object"], schema.type
  end

  it "will expand patternProperties" do
    expand
    assert_equal [], error_messages
    # value ([1]) of the #first tuple in hash
    schema = @schema.properties["app"].definitions["roles"].
      pattern_properties.first[1]
    assert_equal ["string"], schema.type
  end

  it "will expand hyperschema link schemas" do
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"].links[0].schema.properties["name"]
    assert_equal ["string"], schema.type
  end

  it "will expand hyperschema link targetSchemas" do
    expand
    assert_equal [], error_messages
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
    assert_equal [], error_messages
    schema = @schema.properties["app0"]
    assert_equal ["object"], schema.type
  end

  it "will resolve circular dependencies" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#" }
    )
    expand
    assert_equal [], error_messages
    schema = @schema.properties["app"]
    assert_equal ["object"], schema.type
  end

  it "builds appropriate JSON Pointers for expanded references" do
    expand
    assert_equal [], error_messages

    # the *referenced* schema should still have a proper pointer
    schema = @schema.definitions["app"].definitions["name"]
    assert_equal "#/definitions/app/definitions/name", schema.pointer

    # the *reference* schema should have expanded a pointer
    schema = @schema.properties["app"].properties["name"]
    assert_equal "#/definitions/app/properties/name", schema.pointer
  end

  # clones are special in that they retain their original pointer despite where
  # they've been nested
  it "builds appropriate JSON Pointers for circular dependencies" do
    pointer("#/properties").merge!(
      "app"  => { "$ref" => "#" },
      "app1" => { "$ref" => "#/properties/app"}
    )
    expand

    # the first self reference has the standard pointer as expected
    schema = @schema.properties["app"]
    assert_equal "#/properties/app", schema.pointer

    # but diving deeper results in the same pointer again
    schema = schema.properties["app"]
    assert_equal "#/properties/app", schema.pointer

    schema = @schema.properties["app1"]
    assert_equal "#/properties/app1", schema.pointer

    schema = schema.properties["app1"]
    assert_equal "#/properties/app1", schema.pointer
  end

  it "errors on a JSON Pointer that can't be resolved" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#/definitions/nope" }
    )
    refute expand
    assert_includes error_messages, %{Couldn't resolve pointer "#/definitions/nope".}
    assert_includes error_types, :unresolved_pointer
    assert_includes error_messages, %{Couldn't resolve references: #/definitions/nope.}
    assert_includes error_types, :unresolved_references
  end

  it "errors on a URI that can't be resolved" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "/schemata/user#/definitions/name" }
    )
    refute expand
    assert_includes error_messages,
      %{Couldn't resolve references: /schemata/user#/definitions/name.}
      assert_includes error_types, :unresolved_references
    assert_includes error_messages, %{Couldn't resolve URI: /schemata/user.}
    assert_includes error_types, :unresolved_pointer
  end

  it "errors on a relative URI that cannot be transformed to an absolute" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "relative#definitions/name" }
    )
    refute expand
    assert_includes error_messages,
      %{Couldn't resolve references: relative#definitions/name.}
    assert_includes error_types, :unresolved_references
  end

  it "errors on a reference cycle" do
    pointer("#/properties").merge!(
      "app0" => { "$ref" => "#/properties/app2" },
      "app1" => { "$ref" => "#/properties/app0" },
      "app2" => { "$ref" => "#/properties/app1" },
    )
    refute expand
    properties = "#/properties/app0, #/properties/app1, #/properties/app2"
    assert_includes error_messages, %{Reference loop detected: #{properties}.}
    assert_includes error_types, :loop_detected
    assert_includes error_messages, %{Couldn't resolve references: #{properties}.}
    assert_includes error_types, :unresolved_references
  end

  it "raises an aggregate error with expand!" do
    pointer("#/properties").merge!(
      "app" => { "$ref" => "#/definitions/nope" }
    )

    schema = JsonSchema::Parser.new.parse!(schema_sample)
    expander = JsonSchema::ReferenceExpander.new

    # don't bother checking the particulars of the error here because we have
    # other tests for that above
    assert_raises JsonSchema::AggregateError do
      expander.expand!(schema)
    end
  end

  it "expands a schema that is just a reference" do
    # First initialize another schema. Give it a fully qualified URI so that we
    # can reference it across schemas.
    schema = JsonSchema::Parser.new.parse!(schema_sample)
    schema.uri = "http://json-schema.org/test"

    # Initialize a store and add our schema to it.
    store = JsonSchema::DocumentStore.new
    store.add_schema(schema)

    # Have the parser parse _just_ a reference. It should resolve to a
    # subschema in the schema that we initialized above.
    schema = JsonSchema::Parser.new.parse!(
      { "$ref" => "http://json-schema.org/test#/definitions/app" }
    )
    expander = JsonSchema::ReferenceExpander.new
    expander.expand!(schema, store: store)

    assert schema.expanded?
  end

  it "expands a schema with a reference to an external schema in a oneOf array" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "id" => "http://json-schema.org/draft-04/schema#",
      "definitions" => {
        "schemaArray" => {
          "type" => "array",
          "minItems" => 1,
          "items" => { "$ref" => "#" }
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema#",
      "id" => "http://json-schema.org/draft-04/hyper-schema#",
      "allOf" => [
        {
          "$ref" => "http://json-schema.org/draft-04/schema#"
        }
      ]
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)

    store = JsonSchema::DocumentStore.new
    expander = JsonSchema::ReferenceExpander.new

    store.add_schema(schema1)
    store.add_schema(schema2)

    expander.expand!(schema2, store: store)

    assert schema1.expanded?
    assert schema2.expanded?
  end

  it "expands a schema with a nested reference to an external schema in a oneOf array" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "id" => "http://json-schema.org/draft-04/schema#",
      "definitions" => {
        "thingy" => {
          "type" => ["string"]
        },
        "schemaArray" => {
          "type" => "array",
          "minItems" => 1,
          "items" => { "$ref" => "#/definitions/thingy" }
        }
      },
      "properties" => {
        "whatsit" => {
          "$ref" => "#/definitions/schemaArray"
        },
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema#",
      "id" => "http://json-schema.org/draft-04/hyper-schema#",
      "allOf" => [
        {
          "$ref" => "http://json-schema.org/draft-04/schema#"
        }
      ]
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)

    store = JsonSchema::DocumentStore.new
    expander = JsonSchema::ReferenceExpander.new

    store.add_schema(schema1)
    store.add_schema(schema2)

    expander.expand!(schema2, store: store)

    assert_equal ["string"], schema2.all_of[0].properties["whatsit"].items.type
  end

  it "expands a schema with a reference to an external schema with a nested external property reference" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "foo" => {
          "$ref" => "http://json-schema.org/b.json#/definitions/bar"
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)
    schema1.uri = "http://json-schema.org/a.json"

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "definitions" => {
        "bar" => {
          "type" => "object",
          "properties" => {
            "omg" => {
              "$ref" => "http://json-schema.org/c.json#/definitions/baz"
            }
          }
        }
      }
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)
    schema2.uri = "http://json-schema.org/b.json"

    sample3 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "definitions" => {
        "baz" => {
          "type" => "string",
          "maxLength" => 3
        }
      }
    }
    schema3 = JsonSchema::Parser.new.parse!(sample3)
    schema3.uri = "http://json-schema.org/c.json"

    # Initialize a store and add our schema to it.
    store = JsonSchema::DocumentStore.new
    store.add_schema(schema1)
    store.add_schema(schema2)
    store.add_schema(schema3)

    expander = JsonSchema::ReferenceExpander.new
    expander.expand!(schema1, store: store)

    assert_equal 3, schema1.properties["foo"].properties["omg"].max_length
  end

  it "it handles oneOf with nested references to an external schema" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "foo" => {
          "$ref" => "http://json-schema.org/b.json#"
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)
    schema1.uri = "http://json-schema.org/a.json"

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "bar" => {
          "oneOf" => [
            {"type" => "null"},
            {"$ref" => "http://json-schema.org/c.json#"}
          ]
        }
      },
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)
    schema2.uri = "http://json-schema.org/b.json"

    sample3 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "baz" => {
          "type" => "string",
          "maxLength" => 3
        }
      }
    }
    schema3 = JsonSchema::Parser.new.parse!(sample3)
    schema3.uri = "http://json-schema.org/c.json"

    # Initialize a store and add our schema to it.
    store = JsonSchema::DocumentStore.new
    store.add_schema(schema1)
    store.add_schema(schema2)
    store.add_schema(schema3)

    expander = JsonSchema::ReferenceExpander.new
    expander.expand(schema1, store: store)

    assert_equal 3, schema1.properties["foo"].properties["bar"].one_of[1].properties["baz"].max_length
  end

  it "does not infinitely recurse when external ref is local to its schema" do
    sample1 = {
      "id" => "http://json-schema.org/draft-04/schema#",
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "properties" => {
        "additionalItems" => {
          "anyOf" => [ { "$ref" => "#" } ]
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)
    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema#",
      "id" => "http://json-schema.org/draft-04/hyper-schema#",
      "allOf" => [
        { "$ref" => "http://json-schema.org/draft-04/schema#" }
      ]
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)

    store = JsonSchema::DocumentStore.new
    expander = JsonSchema::ReferenceExpander.new

    store.add_schema(schema1)
    store.add_schema(schema2)

    expander.expand!(schema2, store: store)

    assert schema1.expanded?
    assert schema2.expanded?
  end

  it "it handles oneOf with nested references to a local schema" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "foo" => {
          "$ref" => "http://json-schema.org/b.json#"
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)
    schema1.uri = "http://json-schema.org/a.json"

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "definitions" => {
        "baz" => {
          "type" => "string",
          "maxLength" => 3
        }
      },
      "properties" => {
        "bar" => {
          "oneOf" => [
            {"type" => "null"},
            {"$ref" => "#/definitions/baz"}
          ]
        }
      },
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)
    schema2.uri = "http://json-schema.org/b.json"

    # Initialize a store and add our schema to it.
    store = JsonSchema::DocumentStore.new
    store.add_schema(schema1)
    store.add_schema(schema2)

    expander = JsonSchema::ReferenceExpander.new
    expander.expand(schema1, store: store)

    assert_equal 3, schema1.properties["foo"].properties["bar"].one_of[1].max_length
  end

  it "expands a schema with a reference to an external schema with a nested local property reference" do
    sample1 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "properties" => {
        "foo" => {
          "$ref" => "http://json-schema.org/b.json#/definitions/bar"
        },
        "foo2" => {
          "$ref" => "http://json-schema.org/b.json#/definitions/baz"
        }
      }
    }
    schema1 = JsonSchema::Parser.new.parse!(sample1)
    schema1.uri = "http://json-schema.org/a.json"

    sample2 = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "type" => "object",
      "definitions" => {
        "bar" => {
          "type" => "object",
          "properties" => {
            "omg" => {
              "$ref" => "#/definitions/baz"
            }
          }
        },
        "baz" => {
          "type" => "string",
          "maxLength" => 3
        }
      }
    }
    schema2 = JsonSchema::Parser.new.parse!(sample2)
    schema2.uri = "http://json-schema.org/b.json"

    # Initialize a store and add our schema to it.
    store = JsonSchema::DocumentStore.new
    store.add_schema(schema1)
    store.add_schema(schema2)

    expander = JsonSchema::ReferenceExpander.new
    expander.expand!(schema1, store: store)

    # These both point to the same definition, 'baz', but
    # 'foo' has a level of indirection.
    assert_equal 3, schema1.properties["foo2"].max_length
    assert_equal 3, schema1.properties["foo"].properties["omg"].max_length
  end

  it "expands a reference to a link" do
    pointer("#/properties").merge!(
      "link" => { "$ref" => "#/links/0" }
    )
    assert expand

    referenced = @schema.links[0]
    reference = @schema.properties["link"]

    assert_equal reference.href, referenced.href
  end

  def error_messages
    @expander.errors.map { |e| e.message }
  end

  def error_types
    @expander.errors.map { |e| e.type }
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
