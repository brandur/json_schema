require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  it "can find data valid" do
    assert validate(data_sample)
  end

  it "validates type" do
    refute validate(4)
    assert_includes error_messages,
      %{Expected data to be of type "object"; value was: 4.}
  end

  it "validates maxItems" do
    local_data = data_sample.dup
    local_data["flags"] = (0...11).to_a
    refute validate(local_data)
    assert_includes error_messages,
      %{Expected array to have no more than 10 item(s), had 11 item(s).}
  end

  it "validates minItems" do
    local_data = data_sample.dup
    local_data["flags"] = []
    refute validate(local_data)
    assert_includes error_messages,
      %{Expected array to have at least 1 item(s), had 0 item(s).}
  end

  def data_sample
    DataScaffold.data_sample
  end

  def error_messages
    @validator.errors.map { |e| e.message }
  end

  def validate(data_sample)
    @schema = JsonSchema.parse!(DataScaffold.schema_sample).definitions["app"]
    @validator = JsonSchema::Validator.new(@schema)
    @validator.validate(data_sample)
  end
end
