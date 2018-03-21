require "test_helper"

require "json_schema"

describe JsonSchema do
  describe ".parse" do
    it "succeeds" do
      schema, errors = JsonSchema.parse(schema_sample)
      assert schema
      assert_nil errors
    end

    it "returns errors on a parsing problem" do
      pointer("#/properties").merge!(
        "app" => 4
      )
      schema, errors = JsonSchema.parse(schema_sample)
      refute schema
      assert_includes errors.map { |e| e.type }, :schema_not_found
    end
  end

  describe ".parse!" do
    it "succeeds on .parse!" do
      assert JsonSchema.parse!(schema_sample)
    end

    it "returns errors on a parsing problem" do
      pointer("#/properties").merge!(
        "app" => 4
      )
      e = assert_raises(JsonSchema::AggregateError) do
        JsonSchema.parse!(schema_sample)
      end
      assert_includes e.message, %{4 is not a valid schema.}
    end
  end

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end
end
