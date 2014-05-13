# json_schema

A JSON Schema V4 and Hyperschema V4 parser and validator.

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
