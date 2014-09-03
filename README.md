# json_schema

A JSON Schema V4 and Hyperschema V4 parser and validator.

Validate some data based on a JSON Schema:

```
gem install json_schema
validate-schema schema.json data.json
```

## Programmatic

``` ruby
require "json"
require "json_schema"

# parse the schema
schema_data = JSON.parse(File.read("schema.json"))
schema = JsonSchema.parse!(schema_data)

# validate some data
data = JSON.parse(File.read("data.json"))
schema.validate!(data)

# iterate through hyperschema links
schema.links.each do |link|
  puts "#{link.method} #{link.href}"
end
```

## Development

Run the test suite with:

```
rake
```

Or run specific suites or tests with:

```
ruby -Ilib -Itest test/json_schema/validator_test.rb
ruby -Ilib -Itest test/json_schema/validator_test.rb -n /anyOf/
```

## Errors

`SchemaError`s indicate a problem with the schema specified, whereas
`ValidationError`s indicate a violation of the schema. Both include a `message`,
which is human-readable and contains information for the developer, and a
`type`, which is one of the following:

### Schema errors

* `schema_not_found`: `$schema` specified was not found
* `unknown_type`: type specified in the schema is not known
* `unresolved_references`: reference could not be resolved
* `loop_detected`: reference loop detected
* `unresolved_pointer`: pointer in document couldn't be resolved
* `scheme_not_supported`: lookup of reference over scheme specified isn't supported
* `invalid_type`: the schema being parsed is not a valid JSON schema, because a value is the wrong type

### Validation errors

* `loop_detected`: validation loop detected - currently this loop detection is disabled as it's too aggressive
* `invalid_type`: type supplied is not allowed by the schema
* `invalid_format`: `format` condition not satisfied
* `invalid_keys`: some keys of a hash supplied aren't allowed
* `any_of_failed`: `anyOf` condition failed
* `all_of_failed`: `allOf` condition failed
* `one_of_failed`: `oneOf` condition failed
* `not_failed`: input matched the `not` schema
* `min_length_failed`: input shorter than `minLength`
* `max_length_failed`: input longer than `maxLength`
* `min_items_failed`: input array smaller than `minItems`
* `max_items_failed`: input array larger than `maxItems`
* `min_failed`: input value too small (under `min`)
* `max_failed`: input value too large (over `max`)
* `min_properties_failed`: fewer than `minProperties` keys in hash
* `max_properties_failed`: more than `maxProperties` keys in hash
* `multiple_of_failed`: input not a multiple of `multipleOf`
* `pattern_failed`: input string didn't match regex `pattern`
* `required_failed`: some `required` keys weren't included
* `unique_items_failed`: array contained duplicates, disallowed by `"uniqueItems": true`