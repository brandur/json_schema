require "test_helper"

require "json_schema"

describe JsonSchema::Validator do
  it "can find data valid" do
    assert validate
  end

  it "validates enum successfully" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "public"
    assert validate
  end

  it "validates enum unsuccessfully" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "personal"
    refute validate
    assert_includes error_messages,
      %{Expected data to be a member of enum ["private", "public"], value was: personal.}
  end

  it "validates type successfully" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )
    @data_sample = { "name" => "cloudnasium" }
    assert validate
  end

  it "validates type unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "type" => ["object"]
    )
    @data_sample = 4
    refute validate
    assert_includes error_messages,
      %{Expected data to be of type "object"; value was: 4.}
  end

  it "validates items with list successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "pattern" => "^[a-z][a-z\\-]*[a-z]$"
      }
    )
    data_sample["flags"] = ["websockets"]
    assert validate
  end

  it "validates items with list unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => {
        "pattern" => "^[a-z][a-z\\-]*[a-z]$"
      }
    )
    data_sample["flags"] = ["1337"]
    refute validate
    assert_includes error_messages,
      %{Expected string to match pattern "/^[a-z][a-z\\-]*[a-z]$/", value was: 1337.}
  end

  it "validates items with tuple successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https"]
    assert validate
  end

  it "validates items with tuple successfully with additionalItems" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "additionalItems" => true,
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar", "https", "websockets"]
    assert validate
  end

  it "validates items with tuple unsuccessfully for not enough items" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "items" => [
        { "enum" => ["bamboo", "cedar"] },
        { "enum" => ["http", "https"] }
      ]
    )
    data_sample["flags"] = ["cedar"]
    refute validate
    assert_includes error_messages,
      %{Expected array to have at least 2 item(s), had 1 item(s).}
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
    refute validate
    assert_includes error_messages,
      %{Expected array to have no more than 2 item(s), had 3 item(s).}
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
    refute validate
    assert_includes error_messages,
      %{Expected data to be a member of enum ["http", "https"], value was: 1337.}
  end

  it "validates maxItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "maxItems" => 10
    )
    data_sample["flags"] = (0...10).to_a
    assert validate
  end

  it "validates maxItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "maxItems" => 10
    )
    data_sample["flags"] = (0...11).to_a
    refute validate
    assert_includes error_messages,
      %{Expected array to have no more than 10 item(s), had 11 item(s).}
  end

  it "validates minItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "minItems" => 1
    )
    data_sample["flags"] = ["websockets"]
    assert validate
  end

  it "validates minItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "minItems" => 1
    )
    data_sample["flags"] = []
    refute validate
    assert_includes error_messages,
      %{Expected array to have at least 1 item(s), had 0 item(s).}
  end

  it "validates uniqueItems successfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "uniqueItems" => true
    )
    data_sample["flags"] = ["websockets"]
    assert validate
  end

  it "validates uniqueItems unsuccessfully" do
    pointer("#/definitions/app/definitions/flags").merge!(
      "uniqueItems" => true
    )
    data_sample["flags"] = ["websockets", "websockets"]
    refute validate
    assert_includes error_messages,
      %{Expected array items to be unique, but duplicate items were found.}
  end

  it "validates maximum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10
    )
    data_sample["id"] = 11
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10 (exclusive: false), value was: 11.}
  end

  it "validates maximum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10
    )
    data_sample["id"] = 10
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10 (exclusive: true), value was: 10.}
  end

  it "validates maximum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.1
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10.0 (exclusive: false), value was: 10.1.}
  end

  it "validates maximum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.0
    refute validate
    assert_includes error_messages,
      %{Expected data to be smaller than maximum 10.0 (exclusive: true), value was: 10.0.}
  end

  it "validates minimum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 1
    )
    data_sample["id"] = 0
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 1 (exclusive: false), value was: 0.}
  end

  it "validates minimum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 1
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 1 (exclusive: true), value was: 1.}
  end

  it "validates minimum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 0.0
    )
    data_sample["cost"] = -0.01
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 0.0 (exclusive: false), value was: -0.01.}
  end

  it "validates minimum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 0.0
    )
    data_sample["cost"] = 0.0
    refute validate
    assert_includes error_messages,
      %{Expected data to be larger than minimum 0.0 (exclusive: true), value was: 0.0.}
  end

  it "validates multipleOf for an integer" do
    pointer("#/definitions/app/definitions/id").merge!(
      "multipleOf" => 2
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{Expected data to be a multiple of 2, value was: 1.}
  end

  it "validates multipleOf for a number" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "multipleOf" => 0.01
    )
    data_sample["cost"] = 0.005
    refute validate
    assert_includes error_messages,
      %{Expected data to be a multiple of 0.01, value was: 0.005.}
  end

  it "validates additionalProperties boolean successfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => true
    )
    data_sample["foo"] = "bar"
    assert validate
  end

  it "validates additionalProperties boolean unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => false
    )
    data_sample["foo"] = "bar"
    refute validate
    assert_includes error_messages, %{Extra keys in object: foo.}
  end

  it "validates additionalProperties schema successfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => {
        "type" => ["boolean"]
      }
    )
    data_sample["foo"] = true
    assert validate
  end

  it "validates additionalProperties schema unsuccessfully" do
    pointer("#/definitions/app").merge!(
      "additionalProperties" => {
        "type" => ["boolean"]
      }
    )
    data_sample["foo"] = 4
    refute validate
    assert_includes error_messages,
      %{Expected data to be of type "boolean"; value was: 4.}
  end

  it "validates simple dependencies" do
    pointer("#/definitions/app/dependencies").merge!(
      "production" => "ssl"
    )
    data_sample["production"] = true
    refute validate
    assert_includes error_messages, %{Missing required keys in object: ssl.}
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
    refute validate
    assert_includes error_messages, %{Expected data to be larger than minimum 20.0 (exclusive: false), value was: 10.0.}
  end

  it "validates maxProperties" do
    pointer("#/definitions/app").merge!(
      "maxProperties" => 0
    )
    data_sample["name"] = "cloudnasium"
    refute validate
    assert_includes error_messages, %{Expected object to have a maximum of 0 property/ies; it had 1.}
  end

  it "validates minProperties" do
    pointer("#/definitions/app").merge!(
      "minProperties" => 2
    )
    data_sample["name"] = "cloudnasium"
    refute validate
    assert_includes error_messages, %{Expected object to have a minimum of 2 property/ies; it had 1.}
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
    refute validate
    assert_includes error_messages,
      %{Expected data to be of type "null/string"; value was: 456.}
  end

  it "validates required" do
    pointer("#/definitions/app/dependencies").merge!(
      "required" => ["name"]
    )
    data_sample.delete("name")
    refute validate
    assert_includes error_messages, %{Missing required keys in object: name.}
  end

  it "validates allOf" do
    pointer("#/definitions/app/definitions/contrived").merge!(
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
    pointer("#/definitions/app/definitions/contrived").merge!(
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
    pointer("#/definitions/app/definitions/contrived").merge!(
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
    pointer("#/definitions/app/definitions/contrived").merge!(
      "not" => { "pattern" => "^$" }
    )
    data_sample["contrived"] = ""
    refute validate
    assert_includes error_messages,
      %{Data matched subschema of "not" condition.}
  end

  it "validates date-time format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40Z"
    assert validate
  end

  it "validates date-time format with time zone successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40-00:00"
    assert validate
  end

  it "validates date-time format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "date-time"
    )
    data_sample["owner"] = "2014-05-13T08:42:40"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "date-time" format, value was: 2014-05-13T08:42:40.}
  end

  it "validates email format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "email"
    )
    data_sample["owner"] = "dwarf@example.com"
    assert validate
  end

  it "validates email format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "email"
    )
    data_sample["owner"] = "@example.com"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "email" format, value was: @example.com.}
  end

  it "validates hostname format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "hostname"
    )
    data_sample["owner"] = "example.com"
    assert validate
  end

  it "validates hostname format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "hostname"
    )
    data_sample["owner"] = "@example.com"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "hostname" format, value was: @example.com.}
  end

  it "validates ipv4 format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv4"
    )
    data_sample["owner"] = "1.2.3.4"
    assert validate
  end

  it "validates ipv4 format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv4"
    )
    data_sample["owner"] = "1.2.3.4.5"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "ipv4" format, value was: 1.2.3.4.5.}
  end

  it "validates ipv6 format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv6"
    )
    data_sample["owner"] = "1::3:4:5:6:7:8"
    assert validate
  end

  it "validates ipv6 format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "ipv6"
    )
    data_sample["owner"] = "1::3:4:5:6:7:8:9"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "ipv6" format, value was: 1::3:4:5:6:7:8:9.}
  end

  it "validates regex format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "regex"
    )
    data_sample["owner"] = "^owner@heroku\.com$"
    assert validate
  end

  it "validates regex format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "regex"
    )
    data_sample["owner"] = "^owner($"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "regex" format, value was: ^owner($.}
  end

  it "validates absolute uri format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "https://example.com"
    assert validate
  end

  it "validates relative uri format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "schemata/app"
    assert validate
  end

  it "validates uri format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uri"
    )
    data_sample["owner"] = "http://"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "uri" format, value was: http://.}
  end

  it "validates uuid format successfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uuid"
    )
    data_sample["owner"] = "01234567-89ab-cdef-0123-456789abcdef"
    assert validate
  end

  it "validates uuid format unsuccessfully" do
    pointer("#/definitions/app/definitions/owner").merge!(
      "format" => "uuid"
    )
    data_sample["owner"] = "123"
    refute validate
    assert_includes error_messages,
      %{Expected data to match "uuid" format, value was: 123.}
  end

  it "validates maxLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "maxLength" => 3
    )
    data_sample["name"] = "abcd"
    refute validate
    assert_includes error_messages,
      %{Expected string to have a maximum length of 3, was 4 character(s) long.}
  end

  it "validates minLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "minLength" => 3
    )
    data_sample["name"] = "ab"
    refute validate
    assert_includes error_messages,
      %{Expected string to have a minimum length of 3, was 2 character(s) long.}
  end

  it "validates pattern" do
    pointer("#/definitions/app/definitions/name").merge!(
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

  def pointer(path)
    JsonPointer.evaluate(schema_sample, path)
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
