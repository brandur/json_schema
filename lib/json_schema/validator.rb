module JsonSchema
  class Validator
    TYPE_MAP = {
      "array"   => Array,
      "boolean" => [FalseClass, TrueClass],
      "integer" => Integer,
      "number"  => Float,
      "null"    => NilClass,
      "object"  => Hash,
      "string"  => String,
    }

    attr_accessor :errors

    def initialize(schema)
      @schema = schema
    end

    def validate(data)
      @errors = []
      validate_data(@schema, data, @errors)
      @errors.size == 0
    end

    def validate!(data)
      if !validate(data)
        raise SchemaError.aggregate(@errors)
      end
    end

    private

    def validate_data(schema, data, errors)
      valid = true

      valid &&= validate_type(schema, data, errors)

      # validation: array
      valid &&= validate_max_items(schema, data, errors)
      valid &&= validate_min_items(schema, data, errors)
      valid &&= validate_unique_items(schema, data, errors)

      # validation: object
      valid &&= validate_required(schema, data, errors, schema.required)

      # validation: schema
      valid &&= validate_all_of(schema, data, errors)
      valid &&= validate_any_of(schema, data, errors)
      valid &&= validate_dependencies(schema, data, errors)
      valid &&= validate_one_of(schema, data, errors)
      valid &&= validate_pattern_properties(schema, data, errors)
      valid &&= validate_properties(schema, data, errors)
      valid &&= validate_not(schema, data, errors)

      valid
    end

    def validate_all_of(schema, data, errors)
      return true if schema.all_of.empty?
      valid = schema.any_of.all? do |subschema|
        validate_data(subschema, data, errors)
      end
      message = %{Data did not match all subschemas of "allOf" condition.}
      errors << SchemaError.new(schema, message) if !valid
      valid
    end

    def validate_any_of(schema, data, errors)
      return true if schema.any_of.empty?
      valid = schema.any_of.any? do |subschema|
        validate_data(subschema, data, {})
      end
      message = %{Data did not match any subschema of "anyOf" condition.}
      errors << SchemaError.new(schema, message) if !valid
      valid
    end

    def validate_dependencies(schema, data, errors)
      return true if schema.dependencies.empty?
      schema.dependencies.each do |key, obj|
        # if the key is not present, the dependency is fulfilled by definition
        next unless value = data[key]
        if obj.is_a?(Schema)
          validate_data(schema, value, errors)
        else
          # if not a schema, value is an array of required fields
          validate_required(schema, data, errors, value)
        end
      end
    end

    def validate_max_items(schema, data, error)
      return true unless schema.max_items
      if data.size <= schema.max_items
        true
      else
        message = %{Expected array to have no more than #{schema.max_items} item(s), had #{data.size} item(s).}
        errors << SchemaError.new(schema, message)
        false
      end
    end

    def validate_min_items(schema, data, error)
      return true unless schema.min_items
      if data.size >= schema.min_items
        true
      else
        message = %{Expected array to have at least #{schema.min_items} item(s), had #{data.size} item(s).}
        errors << SchemaError.new(schema, message)
        false
      end
    end

    def validate_one_of(schema, data, errors)
      return true if schema.one_of.empty?
      num_valid = schema.any_of.count do |subschema|
        validate_data(subschema, data, {})
      end
      message = %{Data did not match exactly one subschema of "anyOf" condition.}
      errors << SchemaError.new(schema, message) if num_valid != 1
      num_valid == 1
    end

    def validate_not(schema, data, errors)
      return true unless schema.not
      # don't bother accumulating these errors, they'll all be worded
      # incorrectly for the inverse condition
      valid = !validate_data(schema.not)
      message = %{Data matched subschema of "not" condition.}
      errors << SchemaError.new(schema, message) if !valid
      valid
    end

    def validate_pattern_properties(schema, data, errors)
      return true if schema.pattern_properties.empty?
      valid = true
      schema.properties.each do |pattern, subschema|
        data.each do |key, value|
          if key =~ pattern
            valid &&= validate_data(subschema, value, errors)
          end
        end
      end
      valid
    end

    def validate_properties(schema, data, errors)
      return true if schema.properties.empty?
      valid = true
      schema.properties.each do |key, subschema|
        if value = data[key]
          valid &&= validate_data(subschema, value, errors)
        end
      end
      valid
    end

    def validate_required(schema, data, errors, required)
      return true if !required || required.empty?
      if (missing = required - data.keys).empty?
        true
      else
        message = %{Missing required keys in object: #{missing.join(", ")}.}
        errors << SchemaError.new(schema, message)
        false
      end
    end

    def validate_type(schema, data, errors)
      valid_types = schema.type.map { |t| TYPE_MAP[t] }.flatten.compact
      if valid_types.any? { |t| data.is_a?(t) }
        true
      else
        message = %{Expected data to be of type "#{schema.type.join("/")}"; value was: #{data.inspect}.}
        errors << SchemaError.new(schema, message)
        false
      end
    end

    def validate_unique_items(schema, data, error)
      return true unless schema.unique_items
      if data.size == data.uniq.size
        true
      else
        message = %{Expected array items to be unique, but duplicate items were found.}
        errors << SchemaError.new(schema, message)
        false
      end
    end
  end
end
