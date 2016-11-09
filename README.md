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

# parse the schema - raise SchemaError if it's invalid
schema_data = JSON.parse(File.read("schema.json"))
schema = JsonSchema.parse!(schema_data)

# expand $ref nodes - raise SchemaError if unable to resolve
schema.expand_references!

# validate some data - raise ValidationError if it doesn't conform
data = JSON.parse(File.read("data.json"))
schema.validate!(data)

# iterate through hyperschema links
schema.links.each do |link|
  puts "#{link.method} #{link.href}"
end
```

Errors have a `message` (for humans), and `type` (for machines).
`ValidationError`s also include a `path`, a JSON pointer to the location in
the supplied document which violated the schema. See [errors](docs/errors.md)
for more info.

Non-bang methods return a two-element array, with `true`/`false` at index 0
to indicate pass/fail, and an array of errors at index 1 (if any).

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

## Release

1. Update the version in `json_schema.gemspec` as appropriate for [semantic
   versioning](http://semver.org) and add details to `CHANGELOG`.
2. Run the `release` task:

    ```
    bundle exec rake release
    ```
