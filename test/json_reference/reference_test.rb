require "test_helper"

require "json_reference"

describe JsonReference::Reference do
  it "expands a reference without a URI" do
    ref = reference("#/definitions")
    assert_nil ref.uri
    assert_equal "#/definitions", ref.pointer
  end

  it "expands a reference with a URI" do
    ref = reference("http://example.com#/definitions")
    assert_equal URI.parse("http://example.com"), ref.uri
    assert_equal "#/definitions", ref.pointer
  end

  it "expands just a root sign" do
    ref = reference("#")
    assert_nil ref.uri
    assert_equal "#", ref.pointer
  end

  it "expands a URI with just a root sign" do
    ref = reference("http://example.com#")
    assert_equal URI.parse("http://example.com"), ref.uri
    assert_equal "#", ref.pointer
  end

  it "normalizes pointers by adding a root sign prefix" do
    ref = reference("/definitions")
    assert_nil ref.uri
    assert_equal "#/definitions", ref.pointer
  end

  it "normalizes pointers by stripping a trailing slash" do
    ref = reference("#/definitions/")
    assert_nil ref.uri
    assert_equal "#/definitions", ref.pointer
  end

  def reference(str)
    JsonReference::Reference.new(str)
  end
end
