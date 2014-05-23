module DataScaffold
  def self.data_sample
    {
      "name" => "cloudnasium"
    }
  end

  def self.schema_sample
    {
      "$schema" => "http://json-schema.org/draft-04/hyper-schema",
      "title" => "Example API",
      "description" => "An example API.",
      "type" => [
        "object"
      ],
      "definitions" => {
        "app" => {
          "$schema" => "http://json-schema.org/draft-04/hyper-schema",
          "title" => "App",
          "description" => "An app.",
          "id" => "schemata/app",
          "type" => [
            "object"
          ],
          "definitions" => {
            "config_vars" => {
              "patternProperties" => {
                "^\\w+$" => {
                  "type" => ["null", "string"]
                }
              }
            },
            "contrived" => {
              "allOf" => [
                { "maxLength" => 30 },
                { "minLength" => 3 }
              ],
              "anyOf" => [
                { "minLength" => 3 },
                { "minLength" => 5 }
              ],
              "oneOf" => [
                { "pattern" => "^(foo|aaa)$" },
                { "pattern" => "^(foo|zzz)$" }
              ],
              "not" => { "pattern" => "^$" }
            },
            "contrived_plus" => {
              "allOf" => [
                { "$ref" => "/schemata/app#/definitions/contrived/allOf/0" },
                { "$ref" => "/schemata/app#/definitions/contrived/allOf/1" }
              ],
              "anyOf" => [
                { "$ref" => "/schemata/app#/definitions/contrived/anyOf/0" },
                { "$ref" => "/schemata/app#/definitions/contrived/anyOf/1" }
              ],
              "oneOf" => [
                { "$ref" => "/schemata/app#/definitions/contrived/oneOf/0" },
                { "$ref" => "/schemata/app#/definitions/contrived/oneOf/1" }
              ],
              "not" => {
                "$ref" => "/schemata/app#/definitions/contrived/not"
              }
            },
            "cost" => {
              "description" => "running price of an app",
              "example" => 35.01,
              "maximum" => 1000.00,
              "exclusiveMaximum" => true,
              "minimum" => 0.0,
              "exclusiveMinimum" => false,
              "multipleOf" => 0.01,
              "readOnly" => false,
              "type" => ["number"],
            },
            "flags" => {
              "description" => "flags for an app",
              "example" => ["websockets"],
              "items" => {
                "pattern" => "^[a-z][a-z\\-]*[a-z]$"
              },
              "maxItems" => 10,
              "minItems" => 1,
              "readOnly" => false,
              "type" => ["array"],
              "uniqueItems" => true
            },
            "id" => {
              "description" => "integer identifier of an app",
              "example" => 1,
              "maximum" => 10000,
              "exclusiveMaximum" => false,
              "minimum" => 0,
              "exclusiveMinimum" => true,
              "multipleOf" => 1,
              "readOnly" => true,
              "type" => ["integer"],
            },
            "identity" => {
              "anyOf" => [
                { "$ref" => "/schemata/app#/definitions/id" },
                { "$ref" => "/schemata/app#/definitions/name" },
              ]
            },
            "name" => {
              "default" => "hello-world",
              "description" => "unique name of app",
              "example" => "name",
              "maxLength" => 30,
              "minLength" => 3,
              "pattern" => "^[a-z][a-z0-9-]{3,30}$",
              "readOnly" => false,
              "type" => ["string"]
            },
            "owner" => {
              "description" => "owner of the app",
              "format" => "email",
              "example" => "dwarf@example.com",
              "readOnly" => false,
              "type" => ["string"]
            },
            "production" => {
              "description" => "whether this is a production app",
              "example" => false,
              "readOnly" => false,
              "type" => ["boolean"]
            },
            "role" => {
              "description" => "name of a role on an app",
              "example" => "collaborator",
              "readOnly" => true,
              "type" => ["string"],
            },
            "roles" => {
              "additionalProperties" => true,
              "patternProperties" => {
                "^\\w+$" => {
                  "$ref" => "/schemata/app#/definitions/role"
                }
              }
            },
            "ssl" => {
              "description" => "whether this app has SSL termination",
              "example" => false,
              "readOnly" => false,
              "type" => ["boolean"]
            },
            "visibility" => {
              "description" => "the visibility of hte app",
              "enum" => ["private", "public"],
              "example" => false,
              "readOnly" => false,
              "type" => ["string"]
            },
          },
          "properties" => {
            "config_vars" => {
              "$ref" => "/schemata/app#/definitions/config_vars"
            },
            "contrived" => {
              "$ref" => "/schemata/app#/definitions/contrived"
            },
            "cost" => {
              "$ref" => "/schemata/app#/definitions/cost"
            },
            "flags" => {
              "$ref" => "/schemata/app#/definitions/flags"
            },
            "id" => {
              "$ref" => "/schemata/app#/definitions/id"
            },
            "name" => {
              "$ref" => "/schemata/app#/definitions/name"
            },
            "owner" => {
              "$ref" => "/schemata/app#/definitions/owner"
            },
            "production" => {
              "$ref" => "/schemata/app#/definitions/production"
            },
            "ssl" => {
              "$ref" => "/schemata/app#/definitions/ssl"
            },
            "visibility" => {
              "$ref" => "/schemata/app#/definitions/visibility"
            }
          },
          "additionalProperties" => false,
          "dependencies" => {
            "production" => "ssl",
            "ssl" => {
              "properties" => {
                "cost" => {
                  "minimum" => 20.0,
                },
                "name" => {
                  "$ref" => "/schemata/app#/definitions/name"
                },
              }
            }
          },
          "maxProperties" => 10,
          "minProperties" => 1,
          "required" => ["name"],
          "links" => [
            "description" => "Create a new app.",
            "href" => "/apps",
            "method" => "POST",
            "rel" => "create",
            "schema" => {
              "properties" => {
                "name" => {
                  "$ref" => "#/definitions/app/definitions/name"
                },
              }
            },
            "targetSchema" => {
              "$ref" => "#/definitions/app"
            }
          ],
          "media" => {
            "type" => "application/json"
          },
          "pathStart" => "/",
          "readOnly" => false
        }
      },
      "properties" => {
        "app" => {
          "$ref" => "#/definitions/app"
        },
      },
      "links" => [
        {
          "href" => "http://example.com",
          "rel" => "self"
        }
      ]
    }
  end
end
