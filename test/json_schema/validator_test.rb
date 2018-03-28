require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  after do
    JsonSchema.configuration.reset!
  end

  it "can find data valid" do
    assert_valid
  end

  it "validates enum successfully" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "public"
    assert_valid
  end

  it "validates enum unsuccessfully" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "personal"
    refute_valid
    assert_includes error_messages,
      %{personal is not a member of ["private", "public"].}
    assert_includes error_types, :invalid_type
  end

  it "validates type successfully" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )
    @data_sample = { "name" => "cloudnasium" }
    assert_valid
  end

  it "validates sub-type successfully" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )
    class SomeClass < Hash; end
    @data_sample = SomeClass.new
    @data_sample["name"] = "yayrails"
    assert_valid
  end

  it "validates type unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )
    @data_sample = 4
    refute_valid
    assert_includes error_messages, %{For 'definitions/app', 4 is not an object.}
    assert_includes error_types, :invalid_type
    assert_includes error_data, 4
  end

  it "provides accurate error messages for multiple type errors" do
    pointer("#/definitions/app").merge!(
      "type" => ["string"]
    )
    @data_sample = 4
    refute_valid
    assert_includes error_messages, %{For 'definitions/app', 4 is not a string.}
    assert_includes error_types, :invalid_type

    pointer("#/definitions/app").merge!(
      "type" => ["string", "null"]
    )
    @data_sample = 4
    refute_valid
    assert_includes error_messages, %{For 'definitions/app', 4 is not a string or null.}
    assert_includes error_types, :invalid_type

    pointer("#/definitions/app").merge!(
      "type" => ["object", "null", "string"]
    )
    @data_sample = 4
    refute_valid
    assert_includes error_messages, %{For 'definitions/app', 4 is not an object, null, or string.}
    assert_includes error_types, :invalid_type
  end

  it "validates items with list successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "pattern" => "^[a-z][a-z\\-]*[a-z]$"
      }
    )
    data_sample["flags"] = ["websockets"]
    assert_valid
  end

  it "validates items with list unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "pattern" => "^[a-z][a-z\\-]*[a-z]$"
      }
    )
    data_sample["flags"] = ["1337"]
    refute_valid
    assert_includes error_messages,
      %{1337 does not match /^[a-z][a-z\\-]*[a-z]$/.}
    assert_includes error_types, :pattern_failed
    assert_includes error_data, "1337"
  end

  it "validates items with tuple successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https"]
    assert_valid
  end

  it "validates items with tuple with additionalItems boolean successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => true,
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    assert_valid
  end

  it "validates items with tuple with additionalItems boolean unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => false,
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    refute_valid
    assert_includes error_messages, %{No more than 2 items are allowed; 3 were supplied.}
    assert_includes error_types, :max_items_failed
    assert_includes error_data, ["cedar", "https", "websockets"]
  end

  it "validates items with tuple with additionalItems schema successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => { "enum" => [ "foo", "websockets" ] },
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    assert_valid
  end

  it "validates items with tuple with additionalItems schema unsuccessfully for non-conforming additional item" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => { "enum" => [ "foo", "bar" ] },
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    refute_valid
    assert_includes error_messages,
      %{websockets is not a member of ["foo", "bar"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "websockets"
  end

  it "validates items with tuple with additionalItems schema unsuccessfully with multiple failures" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => { "enum" => [ "foo", "bar" ] },
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets", "1337"]
    refute_valid
    assert_includes error_messages,
      %{websockets is not a member of ["foo", "bar"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "websockets"
    assert_includes error_messages,
      %{1337 is not a member of ["foo", "bar"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "1337"
  end

  it "validates items with tuple with additionalItems schema unsuccessfully with non-conforming items and additional items" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => { "enum" => [ "foo", "bar" ] },
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "1337", "websockets"]
    refute_valid
    assert_includes error_messages,
      %{websockets is not a member of ["foo", "bar"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "websockets"
    assert_includes error_messages,
      %{1337 is not a member of ["http", "https"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "1337"
  end

  it "validates items with tuple unsuccessfully for not enough items" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar"]
    refute_valid
    assert_includes error_messages,
      %{2 items required; only 1 was supplied.}
    assert_includes error_types, :min_items_failed
    assert_includes error_data, ["cedar"]
  end

  it "validates items with tuple unsuccessfully for too many items" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => false,
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    refute_valid
    assert_includes error_messages,
      %{No more than 2 items are allowed; 3 were supplied.}
      assert_includes error_types, :max_items_failed
      assert_includes error_data, ["cedar", "https", "websockets"]
  end

  it "validates items with tuple unsuccessfully for non-conforming items" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => false,
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "1337"]
    refute_valid
    assert_includes error_messages,
      %{1337 is not a member of ["http", "https"].}
    assert_includes error_types, :invalid_type
    assert_includes error_data, "1337"
  end

  it "validates maxItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "maxItems" => 10
    )
    data_sample["flags"] = (0...10).to_a
    assert_valid
  end

  it "validates maxItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "maxItems" => 10
    )
    data_sample["flags"] = (0...11).to_a
    refute_valid
    assert_includes error_messages,
      %{No more than 10 items are allowed; 11 were supplied.}
    assert_includes error_types, :max_items_failed
    assert_includes error_data, (0...11).to_a
  end

  it "validates minItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "minItems" => 1
    )
    data_sample["flags"] = ["websockets"]
    assert_valid
  end

  it "validates minItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "minItems" => 1
    )
    data_sample["flags"] = []
    refute_valid
    assert_includes error_messages, %{1 item required; only 0 were supplied.}
    assert_includes error_types, :min_items_failed
    assert_includes error_data, []
  end

  it "validates uniqueItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "uniqueItems" => true
    )
    data_sample["flags"] = ["websockets"]
    assert_valid
  end

  it "validates uniqueItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "uniqueItems" => true
    )
    data_sample["flags"] = ["websockets", "websockets"]
    refute_valid
    assert_includes error_messages, %{Duplicate items are not allowed.}
    assert_includes error_types, :unique_items_failed
    assert_includes error_data, ["websockets", "websockets"]
  end

  it "validates maximum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10
    )
    data_sample["id"] = 11
    refute_valid
    assert_includes error_messages, %{11 must be less than or equal to 10.}
    assert_includes error_types, :max_failed
    assert_includes error_data, 11
  end

  it "validates maximum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10
    )
    data_sample["id"] = 10
    refute_valid
    assert_includes error_messages, %{10 must be less than 10.}
    assert_includes error_types, :max_failed
  end

  it "validates maximum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.1
    refute_valid
    assert_includes error_messages, %{10.1 must be less than or equal to 10.0.}
    assert_includes error_types, :max_failed
  end

  it "validates maximum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.0
    refute_valid
    assert_includes error_messages, %{10.0 must be less than 10.0.}
    assert_includes error_types, :max_failed
  end

  it "validates minimum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 1
    )
    data_sample["id"] = 0
    refute_valid
    assert_includes error_messages, %{0 must be greater than or equal to 1.}
    assert_includes error_types, :min_failed
    assert_includes error_data, 0
  end

  it "validates minimum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 1
    )
    data_sample["id"] = 1
    refute_valid
    assert_includes error_messages, %{1 must be greater than 1.}
  end

  it "validates minimum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 0.0
    )
    data_sample["cost"] = -0.01
    refute_valid
    assert_includes error_messages,
      %{-0.01 must be greater than or equal to 0.0.}
    assert_includes error_types, :min_failed
  end

  it "validates minimum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 0.0
    )
    data_sample["cost"] = 0.0
    refute_valid
    assert_includes error_messages, %{0.0 must be greater than 0.0.}
    assert_includes error_types, :min_failed
  end

  it "validates multipleOf for an integer" do
    pointer("#/definitions/app/definitions/id").merge!(
      "multipleOf" => 2
    )
    data_sample["id"] = 1
    refute_valid
    assert_includes error_messages, %{1 is not a multiple of 2.}
    assert_includes error_types, :multiple_of_failed
    assert_includes error_data, 1
  end

  it "validates multipleOf for a number" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "multipleOf" => 0.01
    )
    data_sample["cost"] = 0.005
    refute_valid
    assert_includes error_messages, %{0.005 is not a multiple of 0.01.}
    assert_includes error_types, :multiple_of_failed
  end

  it "validates additionalProperties boolean successfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => true
    )
    data_sample["foo"] = "bar"
    assert_valid
  end

  it "validates additionalProperties boolean unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => false,
      "patternProperties" => {
        "^matches" => {}
      }
    )
    data_sample["foo"] = "bar"
    data_sample["matches_pattern"] = "yes!"
    refute_valid
    assert_includes error_messages, %{"foo" is not a permitted key.}
    assert_includes error_types, :invalid_keys
  end

  it "validates additionalProperties boolean unsuccessfully with multiple failures" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => false,
      "patternProperties" => {
        "^matches" => {}
      }
    )
    data_sample["foo"] = "bar"
    data_sample["baz"] = "blah"
    data_sample["matches_pattern"] = "yes!"
    refute_valid
    assert_includes error_messages, %{"baz", "foo" are not permitted keys.}
    assert_includes error_types, :invalid_keys
  end

  it "validates additionalProperties schema successfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => {
        "type" => ["boolean"]
      }
    )
    data_sample["foo"] = true
    assert_valid
  end

  it "validates additionalProperties schema unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => {
        "type" => ["boolean"]
      },
      "patternProperties" => {
        "^matches" => {}
      }
    )
    data_sample["foo"] = 4
    data_sample["matches_pattern"] = "yes!"
    refute_valid
    assert_includes error_messages, %{For 'additionalProperties', 4 is not a boolean.}
    assert_includes error_types, :invalid_type
  end

  it "validates simple dependencies" do
    pointer("#/definitions/app/dependencies").merge!(
      "production" => "ssl"
    )
    data_sample["production"] = true
    refute_valid
    assert_includes error_messages,
      %{"ssl" wasn't supplied.}
  end

  it "validates schema dependencies" do
    pointer("#/definitions/app/dependencies").merge!(
      "ssl" => {
        "properties" => {
          "cost" => {
            "minimum" => 20.0,
          }
        }
      }
    )
    data_sample["cost"] = 10.0
    data_sample["ssl"] = true
    refute_valid
    assert_includes error_messages, %{10.0 must be greater than or equal to 20.0.}
    assert_includes error_types, :min_failed
  end

  it "validates maxProperties" do
    pointer("#/definitions/app").merge!(
      "maxProperties" => 0
    )
    data_sample["name"] = "cloudnasium"
    refute_valid
    assert_includes error_messages, %{No more than 0 properties are allowed; 1 was supplied.}
    assert_includes error_types, :max_properties_failed
    assert_includes error_data, { "name" => "cloudnasium" }
  end

  it "validates minProperties" do
    pointer("#/definitions/app").merge!(
      "minProperties" => 2
    )
    data_sample["name"] = "cloudnasium"
    refute_valid
    assert_includes error_messages, %{At least 2 properties are required; 1 was supplied.}
    assert_includes error_types, :min_properties_failed
    assert_includes error_data, { "name" => "cloudnasium" }
  end

  it "validates patternProperties" do
    pointer("#/definitions/app/definitions/config_vars").merge!(
      "patternProperties" => {
        "^\\w+$" => {
          "type" => ["null", "string"]
        }
      }
    )
    data_sample["config_vars"] = {
      ""    => 123,
      "KEY" => 456
    }
    refute_valid
    assert_includes error_messages, %{For 'definitions/config_vars', 456 is not a null or string.}
    assert_includes error_types, :invalid_type
  end

  it "validates patternProperties with missing parent" do
    data_sample["S_0"] = 123

    refute validate_parentless_pattern
    assert_includes error_messages, %{For 'patternProperties/^S_', 123 is not a string.}
    assert_includes error_types, :invalid_type
  end

  it "validates required" do
    pointer("#/definitions/app/dependencies").merge!(
      "required" => ["name"]
    )
    data_sample.delete("name")
    refute_valid
    assert_includes error_messages, %{"name" wasn't supplied.}
    assert_includes error_types, :required_failed
    assert_includes error_data, ["name"]
  end

  it "validates strictProperties successfully" do
    pointer("#/definitions/app").merge!(
      "strictProperties" => false
    )
    assert_valid
  end

  it "validates strictProperties unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "patternProperties" => {
        "^matches" => {}
      },
      "strictProperties" => true
    )
    data_sample["extra_key"] = "value"
    data_sample["matches_pattern"] = "yes!"
    refute_valid
    missing = @schema.properties.keys.sort - ["name"]
    assert_includes error_messages, %{"#{missing.join('", "')}" weren't supplied.}
    assert_includes error_messages, %{"extra_key" is not a permitted key.}
    assert_includes error_types, :invalid_keys
  end

  it "validates allOf" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "allOf" => [
        { "maxLength" => 30 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute_valid
    assert_includes error_messages, %{Not all subschemas of "allOf" matched.}
    assert_includes error_types, :all_of_failed
  end

  it "includes the failing condition when validating allOf" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "allOf" => [
        { "maxLength" => 30 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute_valid
    assert_includes error_messages, %{At least 3 characters are required; only 2 were supplied.}
    assert_includes error_data, "ab"
  end

  it "includes all failing conditions for allOf as sub-errors when all_of_sub_errors is true" do
    JsonSchema.configure do |c|
      c.all_of_sub_errors = true
    end
    pointer("#/definitions/app/definitions/contrived").merge!(
      "allOf" => [
        { "minLength" => 5 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute_valid
    assert_includes error_messages, %{Not all subschemas of "allOf" matched.}
    assert_includes error_types, :all_of_failed
    all_of_error = @validator.errors.find { |error| error.type == :all_of_failed }
    sub_error_messages = all_of_error.sub_errors.map { |errors| errors.map(&:message) }
    sub_error_types = all_of_error.sub_errors.map { |errors| errors.map(&:type) }
    assert_includes sub_error_messages, [%{At least 3 characters are required; only 2 were supplied.}]
    assert_includes sub_error_messages, [%{At least 5 characters are required; only 2 were supplied.}]
    assert_equal sub_error_types, [[:min_length_failed], [:min_length_failed]]
    assert_includes error_data, "ab"
  end

  it "validates anyOf" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "anyOf" => [
        { "minLength" => 5 },
        { "minLength" => 3 }
      ]
    )
    data_sample["contrived"] = "ab"
    refute_valid
    assert_includes error_messages, %{No subschema in "anyOf" matched.}
    assert_includes error_types, :any_of_failed
    any_of_error = @validator.errors.find { |error| error.type == :any_of_failed }
    sub_error_messages = any_of_error.sub_errors.map { |errors| errors.map(&:message) }
    sub_error_types = any_of_error.sub_errors.map { |errors| errors.map(&:type) }
    assert_includes sub_error_messages, [%{At least 5 characters are required; only 2 were supplied.}]
    assert_includes sub_error_messages, [%{At least 3 characters are required; only 2 were supplied.}]
    assert_equal sub_error_types, [[:min_length_failed], [:min_length_failed]]
    assert_includes error_data, "ab"
  end

  it "validates oneOf" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "oneOf" => [
        { "pattern" => "^(foo|aaa)$" },
        { "pattern" => "^(foo|zzz)$" },
        { "pattern" => "^(hell|no)$" }
      ]
    )
    data_sample["contrived"] = "foo"
    refute_valid
    assert_includes error_messages, %{More than one subschema in "oneOf" matched.}
    assert_includes error_types, :one_of_failed
    one_of_error = @validator.errors.find { |error| error.type == :one_of_failed }
    sub_error_messages = one_of_error.sub_errors.map { |errors| errors.map(&:message) }
    sub_error_types = one_of_error.sub_errors.map { |errors| errors.map(&:type) }
    assert_equal sub_error_messages, [[], [], [%{foo does not match /^(hell|no)$/.}]]
    assert_equal sub_error_types, [[], [], [:pattern_failed]]
    assert_includes error_data, "foo"
  end

  it "validates not" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "not" => { "pattern" => "^$" }
    )
    data_sample["contrived"] = ""
    refute_valid
    assert_includes error_messages, %{Matched "not" subschema.}
    assert_includes error_types, :not_failed
    assert_includes error_data, ""
  end

  it "validates date format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date"
    )
    data_sample["owner"] = "2014-05-13"
    assert_valid
  end

  it "validates date format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date"
    )
    data_sample["owner"] = "13/05/2014"
    refute_valid
  end

  it "validates date-time format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40Z"
    assert_valid
  end

  it "validates date-time format with time zone successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40-00:00"
    assert_valid
  end

  it "validates date-time format with time fraction successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40.444Z"
    assert_valid
  end

  it "validates date-time format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40"
    refute_valid
    assert_includes error_messages, %{2014-05-13T08:42:40 is not a valid date-time.}
    assert_includes error_types, :invalid_format
    assert_includes error_data, "2014-05-13T08:42:40"
  end

  it "validates email format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "email"
    )
    data_sample["owner"] = "dwarf@example.com"
    assert_valid
  end

  it "validates email format with long TLDs successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "email"
    )
    data_sample["owner"] = "dwarf@example.technology"
    assert_valid
  end

  it "validates email format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "email"
    )
    data_sample["owner"] = "@example.com"
    refute_valid
    assert_includes error_messages, %{@example.com is not a valid email.}
    assert_includes error_types, :invalid_format
  end

  it "validates hostname format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "hostname"
    )
    data_sample["owner"] = "example.com"
    assert_valid
  end

  it "validates hostname format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "hostname"
    )
    data_sample["owner"] = "@example.com"
    refute_valid
    assert_includes error_messages, %{@example.com is not a valid hostname.}
    assert_includes error_types, :invalid_format
  end

  it "validates ipv4 format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv4"
    )
    data_sample["owner"] = "1.2.3.4"
    assert_valid
  end

  it "validates ipv4 format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv4"
    )
    data_sample["owner"] = "1.2.3.4.5"
    refute_valid
    assert_includes error_messages, %{1.2.3.4.5 is not a valid ipv4.}
    assert_includes error_types, :invalid_format
  end

  it "validates ipv6 format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv6"
    )
    data_sample["owner"] = "1::3:4:5:6:7:8"
    assert_valid
  end

  it "validates ipv6 format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv6"
    )
    data_sample["owner"] = "1::3:4:5:6:7:8:9"
    refute_valid
    assert_includes error_messages, %{1::3:4:5:6:7:8:9 is not a valid ipv6.}
    assert_includes error_types, :invalid_format
  end

  it "validates regex format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "regex"
    )
    data_sample["owner"] = "^owner@heroku\.com$"
    assert_valid
  end

  it "validates regex format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "regex"
    )
    data_sample["owner"] = "^owner($"
    refute_valid
    assert_includes error_messages, %{^owner($ is not a valid regex.}
    assert_includes error_types, :invalid_format
  end

  it "validates absolute uri format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "https://example.com"
    assert_valid
  end

  it "validates relative uri format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "schemata/app"
    assert_valid
  end

  it "validates uri format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "http://example.com[]"
    refute_valid
    assert_includes error_messages, %{http://example.com[] is not a valid uri.}
    assert_includes error_types, :invalid_format
  end

  it "validates absolute uri-reference format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri-reference"
    )
    data_sample["owner"] = "https://example.com"
    assert_valid
  end

  it "validates relative uri format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "#hello"
    assert_valid
  end

  it "validates uri format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri-reference"
    )
    data_sample["owner"] = "http://example.com[]"
    refute_valid
    assert_includes error_messages, %{http://example.com[] is not a valid uri-reference.}
    assert_includes error_types, :invalid_format
  end

  it "validates uuid format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uuid"
    )
    data_sample["owner"] = "01234567-89ab-cdef-0123-456789abcdef"
    assert_valid
  end

  it "validates uuid format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uuid"
    )
    data_sample["owner"] = "123"
    refute_valid
    assert_includes error_messages, %{123 is not a valid uuid.}
    assert_includes error_types, :invalid_format
  end

  it "validates maxLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "maxLength" => 3
    )
    data_sample["name"] = "abcd"
    refute_valid
    assert_includes error_messages, %{Only 3 characters are allowed; 4 were supplied.}
    assert_includes error_types, :max_length_failed
  end

  it "validates minLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "minLength" => 3
    )
    data_sample["name"] = "ab"
    refute_valid
    assert_includes error_messages, %{At least 3 characters are required; only 2 were supplied.}
    assert_includes error_types, :min_length_failed
  end

  it "validates pattern" do
    pointer("#/definitions/app/definitions/name").merge!(
      "pattern" => "^[a-z][a-z0-9-]{3,30}$",
    )
    data_sample["name"] = "ab"
    refute_valid
    assert_includes error_messages, %{ab does not match /^[a-z][a-z0-9-]{3,30}$/.}
    assert_includes error_types, :pattern_failed
    assert_includes error_data, "ab"
  end

  it "builds appropriate JSON Pointers to bad data" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "personal"
    refute_valid
    assert_equal "#/visibility", @validator.errors[0].pointer
  end

=begin
  it "handles a validation loop" do
    pointer("#/definitions/app").merge!(
      "not" => { "$ref" => "#/definitions/app" }
    )
    data_sample["visibility"] = "personal"
    refute_valid
    assert_includes error_messages, %{Validation loop detected.}
  end
=end

  it "validates custom formats successfully" do
    JsonSchema.configure do |c|
      c.register_format "the-answer", ->(data) { data.to_i == 42 }
    end
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "the-answer"
    )
    data_sample["owner"] = "42"
    assert_valid
  end

  it "validates custom formats unsuccessfully" do
    JsonSchema.configure do |c|
      c.register_format "the-answer", ->(data) { data.to_i == 42 }
    end
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "the-answer"
    )
    data_sample["owner"] = "43"
    refute_valid
    assert_includes error_messages, %{43 is not a valid the-answer.}
    assert_includes error_types, :invalid_format
  end

  it "raises an aggregate error with validate!" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )

    schema = JsonSchema.parse!(schema_sample)
    schema.expand_references!
    schema = schema.definitions["app"]
    validator = JsonSchema::Validator.new(schema)

    # don't bother checking the particulars of the error here because we have
    # other tests for that above
    assert_raises JsonSchema::AggregateError do
      validator.validate!(4)
    end
  end

  def data_sample
    @data_sample ||= DataScaffold.data_sample
  end

  def error_messages
    @validator.errors.map(&:message)
  end

  def error_data
    @validator.errors.map(&:data)
  end

  def error_types
    @validator.errors.map(&:type)
  end

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
  end

  def validate_parentless_pattern
    schema = {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "patternProperties" => {
        "^S_" => {
          "type" => [
            "string"
          ]
        }
      }
    }
    schema = JsonSchema.parse!(schema)
    @validator = JsonSchema::Validator.new(schema)
    @validator.validate(data_sample)
  end

  def schema_sample
    @schema_sample ||= DataScaffold.schema_sample
  end

  def validator
    @schema = JsonSchema.parse!(schema_sample)
    @schema.expand_references!
    @schema = @schema.definitions["app"]
    JsonSchema::Validator.new(@schema)
  end

  # assert_valid asserts that both the "fail fast" and the "full error messages"
  # code paths consider the data sample valid for the set schema.
  def assert_valid
    @validator = validator
    assert @validator.validate(data_sample, fail_fast: true)
    assert @validator.validate(data_sample, fail_fast: false)
  end

  # refute_valid asserts that both the "fail fast" and the "full error messages"
  # code paths consider the data sample erroneous for the set schema.
  def refute_valid
    @validator = validator
    refute @validator.validate(data_sample, fail_fast: true)
    refute @validator.validate(data_sample, fail_fast: false)
  end
end
