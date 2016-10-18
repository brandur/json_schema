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
    assert_equal({:schema => :schema, :named => :schema_named},
      obj.class.schema_attrs)
  end

  it "defines attributes with default readers" do
    obj = TestAttributes.new
    assert_equal [], obj.copyable_default
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
      assert_equal nil, obj[:copyable]
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
    assert_equal nil, obj.copyable
    assert_equal nil, obj.schema
  end

  class TestAttributes
    include JsonSchema::Attributes

    def initialize
      initialize_attrs
    end

    attr_copyable :copyable

    attr_schema :schema
    attr_schema :schema_named, :schema_name => :named

    attr_copyable :copyable_default
    attr_reader_default :copyable_default, []
  end

  class TestAttributesDescendant < TestAttributes
    inherit_attrs
  end
end
