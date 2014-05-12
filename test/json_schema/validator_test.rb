require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  it "can find data valid" do
    assert validate(data_sample)
  end

  def data_sample
    DataScaffold.data_sample
  end

  def validate(data_sample)
    @schema = JsonSchema.parse!(DataScaffold.schema_sample)
    @validator = JsonSchema::Validator.new(@schema)
    @validator.validate(data_sample)
  end
end
