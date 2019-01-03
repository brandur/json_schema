require "test_helper"

require "json_schema"

describe JsonSchema::Attributes do
  it "defines copyable attributes" do
    obj = TestAttributes.new
    obj.copyable = "foo"
    assert_equal "foo", obj.copyable
    assert_includes obj.class.copyable_attrs, :@copyable
  end

  it "defines schema attributes" do
    obj = TestAttributes.new
    obj.schema = "foo"
    assert_equal "foo", obj.schema
    assert_equal({:schema => :schema, :named => :schema_named, :cached => :cached},
      obj.class.schema_attrs)
  end

  it "defines attributes with default readers" do
    obj = TestAttributes.new
    assert_equal [], obj.copyable_default

    assert_equal "application/json", obj.copyable_default_with_string

    hash = obj.copyable_default_with_object
    assert_equal({}, hash)
    ex = if defined?(FrozenError)
           FrozenError
         else
           RuntimeError
         end

    assert_raises(ex) do
      hash[:x] = 123
    end

    # This is a check to make sure that the new object is not the same object
    # as the one that we just mutated above. When assigning defaults the module
    # should dup any common data strcutures that it puts in here.
    obj = TestAttributes.new
    hash = obj.copyable_default_with_object
    assert_equal({}, hash)
  end

  it "inherits attributes when so instructed" do
    obj = TestAttributesDescendant.new
    assert_includes obj.class.copyable_attrs, :@copyable
  end

  it "allows schema attributes to be indexed but not others" do
    obj = TestAttributes.new

    obj.copyable = "non-schema"
    obj.schema = "schema"

    assert_raises NoMethodError do
      assert_nil obj[:copyable]
    end

    assert_equal "schema", obj[:schema]
  end

  it "copies attributes with #copy_from" do
    obj = TestAttributes.new

    obj.copyable = "copyable"
    obj.schema = "schema"

    obj2 = TestAttributes.new
    obj2.copy_from(obj)

    assert_equal "copyable", obj2.copyable
    assert_equal "schema", obj2.schema
  end

  it "initializes attributes with #initialize_attrs" do
    obj = TestAttributes.new

    # should produce a nil value *without* a Ruby warning
    assert_nil obj.copyable
    assert_nil obj.schema
  end

  it "cleans cached values when assigning parent attribute" do
    obj = TestAttributes.new

    obj.cached = "test"
    assert_equal "test_123", obj.cached_parsed

    obj.cached = "other"
    assert_equal "other_123", obj.cached_parsed
  end

  class TestAttributes
    include JsonSchema::Attributes

    def initialize
      initialize_attrs
    end

    attr_copyable :copyable

    attr_schema :schema
    attr_schema :schema_named, :schema_name => :named

    attr_schema :cached, :clear_cache => :@cached_parsed
    def cached_parsed
      @cached_parsed ||= "#{cached}_123"
    end

    attr_copyable :copyable_default, :default => []
    attr_copyable :copyable_default_with_string, :default => "application/json"
    attr_copyable :copyable_default_with_object, :default => {}
  end

  class TestAttributesDescendant < TestAttributes
    inherit_attrs
  end
end
