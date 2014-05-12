require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  it "can find data valid" do
    assert validate
  end

  it "validates type" do
    pointer(schema_sample, "#/definitions/app").merge!(
      "type" => ["object"]
    )
    @data_sample = 4
    refute validate
    assert_includes error_messages,
      %{Expected data to be of type "object"; value was: 4.}
  end

  it "validates maxItems" do
    pointer(schema_sample, "#/definitions/app/definitions/flags").merge!(
      "maxItems" => 10
    )
    data_sample["flags"] = (0...11).to_a
    refute validate
    assert_includes error_messages,
      %{Expected array to have no more than 10 item(s), had 11 item(s).}
  end

  it "validates minItems" do
    pointer(schema_sample, "#/definitions/app/definitions/flags").merge!(
      "minItems" => 1
    )
    data_sample["flags"] = []
    refute validate
    assert_includes error_messages,
      %{Expected array to have at least 1 item(s), had 0 item(s).}
  end

  it "validates uniqueItems" do
    pointer(schema_sample, "#/definitions/app/definitions/flags").merge!(
      "uniqueItems" => true
    )
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
    pointer(schema_sample, "#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.1
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10.0 (exclusive: false), value was: 10.1.}
  end

  it "validates maximum for a number with exclusiveMaximum true" do
    pointer(schema_sample, "#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.0
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10.0 (exclusive: true), value was: 10.0.}
  end

  it "validates minimum for an integer with exclusiveMaximum false" do
    pointer(schema_sample, "#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 1
    )
    data_sample["id"] = 0
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 1 (exclusive: false), value was: 0.}
  end

  it "validates minimum for an integer with exclusiveMaximum true" do
    pointer(schema_sample, "#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 1
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 1 (exclusive: true), value was: 1.}
  end

  it "validates minimum for a number with exclusiveMaximum false" do
    pointer(schema_sample, "#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 0.0
    )
    data_sample["cost"] = -0.01
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 0.0 (exclusive: false), value was: -0.01.}
  end

  it "validates minimum for a number with exclusiveMaximum true" do
    pointer(schema_sample, "#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 0.0
    )
    data_sample["cost"] = 0.0
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 0.0 (exclusive: true), value was: 0.0.}
  end

  it "validates multipleOf for an integer" do
    pointer(schema_sample, "#/definitions/app/definitions/id").merge!(
      "multipleOf" => 2
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{Expected data to be a multiple of 2, value was: 1.}
  end

  it "validates multipleOf for a number" do
    pointer(schema_sample, "#/definitions/app/definitions/cost").merge!(
      "multipleOf" => 0.01
    )
    data_sample["cost"] = 0.005
    refute validate
    assert_includes error_messages,
      %{Expected data to be a multiple of 0.01, value was: 0.005.}
  end

  # placeholder

  it "validates allOf" do
    pointer(schema_sample, "#/definitions/app/definitions/contrived").merge!(
      "allOf" => [
        { "maxLength" => 30 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute validate
    assert_includes error_messages,
      %{Expected string to have a minimum length of 3, was 2 character(s) long.}
  end

  it "validates anyOf" do
    pointer(schema_sample, "#/definitions/app/definitions/contrived").merge!(
      "anyOf" => [
        { "minLength" => 5 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute validate
    assert_includes error_messages,
      %{Data did not match any subschema of "anyOf" condition.}
  end

  it "validates oneOf" do
    pointer(schema_sample, "#/definitions/app/definitions/contrived").merge!(
      "oneOf" => [
        { "pattern" => "^(foo|aaa)$" },
        { "pattern" => "^(foo|zzz)$" }
      ]
    )
    data_sample["contrived"] = "foo"
    refute validate
    assert_includes error_messages,
      %{Data did not match exactly one subschema of "oneOf" condition.}
  end

  it "validates not" do
    pointer(schema_sample, "#/definitions/app/definitions/contrived").merge!(
      "not" => { "pattern" => "^$" }
    )
    data_sample["contrived"] = ""
    refute validate
    assert_includes error_messages,
      %{Data matched subschema of "not" condition.}
  end

  it "validates maxLength" do
    pointer(schema_sample, "#/definitions/app/definitions/name").merge!(
      "maxLength" => 3
    )
    data_sample["name"] = "abcd"
    refute validate
    assert_includes error_messages,
      %{Expected string to have a maximum length of 3, was 4 character(s) long.}
  end

  it "validates minLength" do
    pointer(schema_sample, "#/definitions/app/definitions/name").merge!(
      "minLength" => 3
    )
    data_sample["name"] = "ab"
    refute validate
    assert_includes error_messages,
      %{Expected string to have a minimum length of 3, was 2 character(s) long.}
  end

  it "validates pattern" do
    pointer(schema_sample, "#/definitions/app/definitions/name").merge!(
      "pattern" => "^[a-z][a-z0-9-]{3,30}$",
    )
    data_sample["name"] = "ab"
    refute validate
    assert_includes error_messages,
      %{Expected string to match pattern "/^[a-z][a-z0-9-]{3,30}$/", value was: ab.}
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
