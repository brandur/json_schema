require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  it "can find data valid" do
    assert validate
  end

  it "validates type" do
    @data_sample = 4
    refute validate
    assert_includes error_messages,
      %{Expected data to be of type "object"; value was: 4.}
  end

  it "validates maxItems" do
    data_sample["flags"] = (0...11).to_a
    refute validate
    assert_includes error_messages,
      %{Expected array to have no more than 10 item(s), had 11 item(s).}
  end

  it "validates minItems" do
    data_sample["flags"] = []
    refute validate
    assert_includes error_messages,
      %{Expected array to have at least 1 item(s), had 0 item(s).}
  end

  it "validates uniqueItems" do
    data_sample["flags"] = [1, 1]
    refute validate
    assert_includes error_messages,
      %{Expected array items to be unique, but duplicate items were found.}
  end

  it "validates maximum for an integer with exclusiveMaximum false" do
    pointer(schema_sample, "#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10
    )
    data_sample["id"] = 11
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10 (exclusive: false), value was: 11.}
  end

  it "validates maximum for an integer with exclusiveMaximum true" do
    pointer(schema_sample, "#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10
    )
    data_sample["id"] = 10
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10 (exclusive: true), value was: 10.}
  end

  it "validates maximum for a number with exclusiveMaximum false" do
  end

  it "validates maximum for a number with exclusiveMaximum true" do
  end

  it "validates minimum for an integer with exclusiveMaximum false" do
  end

  it "validates minimum for an integer with exclusiveMaximum true" do
  end

  it "validates minimum for a number with exclusiveMaximum false" do
  end

  it "validates minimum for a number with exclusiveMaximum true" do
  end

  def data_sample
    @data_sample ||= DataScaffold.data_sample
  end

  def error_messages
    @validator.errors.map { |e| e.message }
  end

  def pointer(data, path)
    JsonPointer.evaluate(data, path)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end

  def validate
    @schema = JsonSchema.parse!(schema_sample).definitions["app"]
    @validator = JsonSchema::Validator.new(@schema)
    @validator.validate(data_sample)
  end
end
