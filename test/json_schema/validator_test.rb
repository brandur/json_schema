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
      %{personal is not a member of ["private", "public"].}
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
      %{4 is not a object.}
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
      %{1337 does not match /^[a-z][a-z\\-]*[a-z]$/.}
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
      %{2 items required; only 1 was supplied.}
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
      %{No more than 2 items are allowed; 3 were supplied.}
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
      %{1337 is not a member of ["http", "https"].}
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
      %{No more than 10 items are allowed; 11 were supplied.}
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
      %{1 item required; only 0 were supplied.}
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
    assert_includes error_messages, %{Duplicate items are not allowed.}
  end

  it "validates maximum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10
    )
    data_sample["id"] = 11
    refute validate
    assert_includes error_messages, %{11 must be less than or equal to 10.}
  end

  it "validates maximum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10
    )
    data_sample["id"] = 10
    refute validate
    assert_includes error_messages, %{10 must be less than 10.}
  end

  it "validates maximum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => false,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.1
    refute validate
    assert_includes error_messages, %{10.1 must be less than or equal to 10.0.}
  end

  it "validates maximum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMaximum" => true,
      "maximum"          => 10.0
    )
    data_sample["cost"] = 10.0
    refute validate
    assert_includes error_messages,
      %{10.0 must be less than 10.0.}
  end

  it "validates minimum for an integer with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 1
    )
    data_sample["id"] = 0
    refute validate
    assert_includes error_messages,
      %{0 must be greater than or equal to 1.}
  end

  it "validates minimum for an integer with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/id").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 1
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{1 must be greater than 1.}
  end

  it "validates minimum for a number with exclusiveMaximum false" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => false,
      "minimum"          => 0.0
    )
    data_sample["cost"] = -0.01
    refute validate
    assert_includes error_messages,
      %{-0.01 must be greater than or equal to 0.0.}
  end

  it "validates minimum for a number with exclusiveMaximum true" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "exclusiveMinimum" => true,
      "minimum"          => 0.0
    )
    data_sample["cost"] = 0.0
    refute validate
    assert_includes error_messages,
      %{0.0 must be greater than 0.0.}
  end

  it "validates multipleOf for an integer" do
    pointer("#/definitions/app/definitions/id").merge!(
      "multipleOf" => 2
    )
    data_sample["id"] = 1
    refute validate
    assert_includes error_messages,
      %{1 is not a multiple of 2.}
  end

  it "validates multipleOf for a number" do
    pointer("#/definitions/app/definitions/cost").merge!(
      "multipleOf" => 0.01
    )
    data_sample["cost"] = 0.005
    refute validate
    assert_includes error_messages,
      %{0.005 is not a multiple of 0.01.}
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
      "additionalProperties" => false,
      "patternProperties" => {
        "^matches" => {}
      }
    )
    data_sample["foo"] = "bar"
    data_sample["matches_pattern"] = "yes!"
    refute validate
    assert_includes error_messages, %{"foo" is not a permitted key.}
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
    refute validate
    assert_includes error_messages, %{"baz", "foo" are not permitted keys.}
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
      },
      "patternProperties" => {
        "^matches" => {}
      }
    )
    data_sample["foo"] = 4
    data_sample["matches_pattern"] = "yes!"
    refute validate
    assert_includes error_messages,
      %{4 is not a boolean.}
  end

  it "validates simple dependencies" do
    pointer("#/definitions/app/dependencies").merge!(
      "production" => "ssl"
    )
    data_sample["production"] = true
    refute validate
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
    refute validate
    assert_includes error_messages, %{10.0 must be greater than or equal to 20.0.}
  end

  it "validates maxProperties" do
    pointer("#/definitions/app").merge!(
      "maxProperties" => 0
    )
    data_sample["name"] = "cloudnasium"
    refute validate
    assert_includes error_messages, %{No more than 0 properties are allowed; 1 was supplied.}
  end

  it "validates minProperties" do
    pointer("#/definitions/app").merge!(
      "minProperties" => 2
    )
    data_sample["name"] = "cloudnasium"
    refute validate
    assert_includes error_messages, %{At least 10 properties are required; 1 was supplied.}
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
      %{456 is not a null/string.}
  end

  it "validates required" do
    pointer("#/definitions/app/dependencies").merge!(
      "required" => ["name"]
    )
    data_sample.delete("name")
    refute validate
    assert_includes error_messages,
      %{"name" wasn't supplied.}
  end

  it "validates strictProperties successfully" do
    pointer("#/definitions/app").merge!(
      "strictProperties" => false
    )
    assert validate
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
    refute validate
    missing = @schema.properties.keys.sort - ["name"]
    assert_includes error_messages,
      %{"#{missing.join('", "')}" weren't supplied.}
    assert_includes error_messages, %{"extra_key" is not a permitted key.}
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
      %{At least 3 characters are required; only 2 were supplied.}
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
      %{No subschema in "anyOf" matched.}
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
      %{More than one subschema in "oneOf" matched.}
  end

  it "validates not" do
    pointer("#/definitions/app/definitions/contrived").merge!(
      "not" => { "pattern" => "^$" }
    )
    data_sample["contrived"] = ""
    refute validate
    assert_includes error_messages,
      %{Matched "not" subschema.}
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
      %{2014-05-13T08:42:40 is not a valid date-time.}
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
      %{@example.com is not a valid email.}
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
      %{@example.com is not a valid hostname.}
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
      %{1.2.3.4.5 is not a valid ipv4.}
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
      %{1::3:4:5:6:7:8:9 is not a valid ipv6.}
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
      %{^owner($ is not a valid regex.}
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
      %{http:// is not a valid uri.}
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
      %{123 is not a valid uuid.}
  end

  it "validates maxLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "maxLength" => 3
    )
    data_sample["name"] = "abcd"
    refute validate
    assert_includes error_messages,
      %{Only 3 characters are allowed; 4 were supplied.}
  end

  it "validates minLength" do
    pointer("#/definitions/app/definitions/name").merge!(
      "minLength" => 3
    )
    data_sample["name"] = "ab"
    refute validate
    assert_includes error_messages,
      %{At least 3 characters are required; only 2 were supplied.}
  end

  it "validates pattern" do
    pointer("#/definitions/app/definitions/name").merge!(
      "pattern" => "^[a-z][a-z0-9-]{3,30}$",
    )
    data_sample["name"] = "ab"
    refute validate
    assert_includes error_messages,
      %{ab does not match /^[a-z][a-z0-9-]{3,30}$/.}
  end

  it "builds appropriate JSON Pointers to bad data" do
    pointer("#/definitions/app/definitions/visibility").merge!(
      "enum" => ["private", "public"]
    )
    data_sample["visibility"] = "personal"
    refute validate
    assert_equal "#/visibility", @validator.errors[0].pointer
  end

=begin
  it "handles a validation loop" do
    pointer("#/definitions/app").merge!(
      "not" => { "$ref" => "#/definitions/app" }
    )
    data_sample["visibility"] = "personal"
    refute validate
    assert_includes error_messages, %{Validation loop detected.}
  end
=end

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
    @schema = JsonSchema.parse!(schema_sample)
    @schema.expand_references!
    @schema = @schema.definitions["app"]
    @validator = JsonSchema::Validator.new(@schema)
    @validator.validate(data_sample)
  end
end
