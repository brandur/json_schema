require "test_helper"

require "json_schema"

describe JsonSchema::DocumentStore do
  before do
    @store = JsonSchema::DocumentStore.new
  end

  it "adds and looks up a schema" do
    schema = schema_sample("http://example.com/schema")
    @store.add_schema(schema)
    assert_equal schema, @store.lookup_schema(schema.uri)
  end

  it "can iterate through its schemas" do
    uri = "http://example.com/schema"
    schema = schema_sample(uri)
    @store.add_schema(schema)
    assert_equal [[uri, schema]], @store.to_a
  end

  it "can lookup a schema added with a document root sign" do
    uri = "http://example.com/schema"
    schema = schema_sample(uri + "#")
    @store.add_schema(schema)
    assert_equal schema, @store.lookup_schema(uri)
  end

  it "can lookup a schema with a document root sign" do
    uri = "http://example.com/schema"
    schema = schema_sample(uri)
    @store.add_schema(schema)
    assert_equal schema, @store.lookup_schema(uri + "#")
  end

  def schema_sample(uri)
    schema = JsonSchema::Schema.new
    schema.uri = uri
    schema
  end
end
