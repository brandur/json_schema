require "test_helper"

require "json_pointer"
require "json_schema"

describe JsonPointer::Evaluator do
  before do
    @evaluator = JsonPointer::Evaluator.new(data)
  end

  it "evaluates pointers according to spec" do
    assert_equal data,           @evaluator.evaluate("")
    assert_equal ["bar", "baz"], @evaluator.evaluate("/foo")
    assert_equal "bar",          @evaluator.evaluate("/foo/0")
    assert_equal 0,              @evaluator.evaluate("/")
    assert_equal 1,              @evaluator.evaluate("/a~1b")
    assert_equal 2,              @evaluator.evaluate("/c%d")
    assert_equal 3,              @evaluator.evaluate("/e^f")
    assert_equal 4,              @evaluator.evaluate("/g|h")
    assert_equal 5,              @evaluator.evaluate("/i\\j")
    assert_equal 6,              @evaluator.evaluate("/k\"l")
    assert_equal 7,              @evaluator.evaluate("/ ")
    assert_equal 8,              @evaluator.evaluate("/m~0n")
  end

  it "takes a leading #" do
    assert_equal 0, @evaluator.evaluate("#/")
  end

  it "returns nils on missing values" do
    assert_nil @evaluator.evaluate("/bar")
  end

  it "raises when a path doesn't being with /" do
    e = assert_raises(ArgumentError) { @evaluator.evaluate("foo") }
    assert_equal %{Path must begin with a leading "/": foo.}, e.message
    e = assert_raises(ArgumentError) { @evaluator.evaluate("#foo") }
    assert_equal %{Path must begin with a leading "/": #foo.}, e.message
  end

  it "raises when a non-digit is specified on an array" do
    e = assert_raises(ArgumentError) { @evaluator.evaluate("/foo/bar") }
    assert_equal %{Key operating on an array must be a digit or "-": bar.},
      e.message
  end

  it "can evaluate on a schema object" do
    schema = JsonSchema.parse!(DataScaffold.schema_sample)
    evaluator = JsonPointer::Evaluator.new(schema)
    res = evaluator.evaluate("#/definitions/app/definitions/contrived/allOf/0")
    assert_kind_of JsonSchema::Schema, res
    assert 30, res.max_length
  end

  def data
   {
      "foo"  => ["bar", "baz"],
      ""     => 0,
      "a/b"  => 1,
      "c%d"  => 2,
      "e^f"  => 3,
      "g|h"  => 4,
      "i\\j" => 5,
      "k\"l" => 6,
      " "    => 7,
      "m~n"  => 8
   }
  end
end
