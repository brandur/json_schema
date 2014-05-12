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

  def data_sample
    DataScaffold.data_sample
  end

  def error_messages
    @validator.errors.map { |e| e.message }
  end

  def validate(data_sample)
    @schema = JsonSchema.parse!(DataScaffold.schema_sample)
    @validator = JsonSchema::Validator.new(@schema)
    @validator.validate(data_sample)
  end
end
