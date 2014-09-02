module JsonSchema
  class SchemaError
    attr_accessor :message, :schema, :type

    def self.aggregate(errors)
      errors.map(&:to_s)
    end

    def initialize(schema, message, type)
      @schema = schema
      @message = message
      @type = type
    end

    def to_s
      "#{schema.pointer}: #{message}"
    end
  end

  class ValidationError < SchemaError
    attr_accessor :path

    def initialize(schema, path, message, type)
      super(schema, message, type)
      @path = path
    end

    def pointer
      path.join("/")
    end

    def to_s
      "#{pointer}: failed schema #{schema.pointer}: #{message}"
    end
  end

  ## Possible types
  ### Schema errors
  # schema_not_found: $schema specified was not found
  # unknown_type: type specified by schema is not known
  # invalid_type: type supplied is not allowed by the schema
  # unresolved_references: reference could not be resolved
  # loop_detected: reference loop detected
  # unresolved_pointer: pointer in document couldn't be resolved
  # scheme_not_supported: lookup of reference over scheme specified isn't supported

  ### Validation errors
  # loop_detected: validation loop detected - currently disabled
  # invalid_type: type mismatch
  # invalid_format: format condition not satisfied
  # invalid_keys: some keys of a hash aren't allowed
  # any_of_failed: anyOf condition failed
  # all_of_failed: allOf condition failed
  # one_of_failed: oneOf condition failed
  # not_failed: input matched the `not` schema
  # min_length_failed: under minLength
  # max_length_failed: over maxLength
  # min_items_failed: under minItems
  # max_items_failed: over maxItems
  # max_failed: value too large (over max)
  # min_failed: value too small (under min)
  # max_properties_failed: too many keys in hash (over maxProperties)
  # min_properties_failed: too few keys in hash (under minProperties)
  # multiple_of_failed: not a multiple of `multipleOf`
  # pattern_failed: string didn't match pattern
  # required_failed: some required keys weren't included
  # unique_items_failed: array contained duplicates, which isn't allowed
end
