# json_schema

A JSON Schema V4 and Hyperschema V4 parser and validator.

``` ruby
require "json"
require "json_schema"

schema_data = JSON.parse(File.read("schema.json"))
schema = JsonSchema.parse!(schema_data)

data = JSON.parse(File.read("data.json"))
schema.validate!(data)
```
