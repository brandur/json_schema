require "test_helper"

require "json_schema"

describe JsonSchema do
  describe ".parse" do
    it "succeeds" do
      JsonSchema.parse(schema_sample)
    end
  end

  describe ".parse!" do
    it "succeeds on .parse!" do
      JsonSchema.parse!(schema_sample)
    end
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end
end
