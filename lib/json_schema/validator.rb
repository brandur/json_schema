require "uri"

module JsonSchema
  class Validator
    attr_accessor :errors

    def initialize(schema)
      @schema = schema
    end

    def validate(data, fail_fast: false)
      @errors = []
      @visits = {}
      @fail_fast = fail_fast

      # This dynamically creates the "strict_or_fast_and" method which is used
      # throughout the validator to combine the previous validation result with
      # another validation check.
      # Logic wise, we could simply define this method without meta programming
      # and decide every time to either call fast_and or strict_end.
      # Unfortunately this has a small overhead, that adds up over the runtime
      # of the validator – about 5% if we check @fail_fast everytime.
      # For more details, please see https://github.com/brandur/json_schema/pull/96
      and_operation = method(@fail_fast ? :fast_and : :strict_and)
      define_singleton_method(:strict_or_fast_and, and_operation)

      catch(:fail_fast) do
        validate_data(@schema, data, @errors, ['#'])
      end
      @errors.size == 0
    end

    def validate!(data, fail_fast: false)
      if !validate(data, fail_fast: fail_fast)
        raise AggregateError.new(@errors)
      end
    end

    private

    def first_visit(schema, errors, path)
      true
# removed until more comprehensive testing can be performed .. this is
# currently causing validation loop detections to go off on all non-trivial
# schemas
=begin
      key = "#{schema.object_id}-#{schema.pointer}-#{path.join("/")}"
      if !@visits.key?(key)
        @visits[key] = true
        true
      else
        message = %{Validation loop detected.}
        errors << ValidationError.new(schema, path, message, :loop_detected)
        false
      end
=end
    end

    # for use with additionalProperties and strictProperties
    def get_extra_keys(schema, data)
      extra = data.keys - schema.properties.keys

      if schema.pattern_properties
        schema.pattern_properties.keys.each do |pattern|
          extra -= extra.select { |k| k =~ pattern }
        end
      end

      extra
    end

    # works around &&'s "lazy" behavior
    def strict_and(valid_old, valid_new)
      valid_old && valid_new
    end

    def fast_and(valid_old, valid_new)
      throw :fail_fast, false if !valid_new
      valid_old && valid_new
    end

    def validate_data(schema, data, errors, path)
      valid = true
      # detect a validation loop
      if !first_visit(schema, errors, path)
        return false
      end

      # validation: any
      valid = strict_or_fast_and valid, validate_all_of(schema, data, errors, path)
      valid = strict_or_fast_and valid, validate_any_of(schema, data, errors, path)
      valid = strict_or_fast_and valid, validate_enum(schema, data, errors, path)
      valid = strict_or_fast_and valid, validate_one_of(schema, data, errors, path)
      valid = strict_or_fast_and valid, validate_not(schema, data, errors, path)
      valid = strict_or_fast_and valid, validate_type(schema, data, errors, path)

      # validation: array
      if data.is_a?(Array)
        valid = strict_or_fast_and valid, validate_items(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_max_items(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_min_items(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_unique_items(schema, data, errors, path)
      end

      # validation: integer/number
      if data.is_a?(Float) || data.is_a?(Integer)
        valid = strict_or_fast_and valid, validate_max(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_min(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_multiple_of(schema, data, errors, path)
      end

      # validation: object
      if data.is_a?(Hash)
        valid = strict_or_fast_and valid, validate_additional_properties(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_dependencies(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_max_properties(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_min_properties(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_pattern_properties(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_properties(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_required(schema, data, errors, path, schema.required)
        valid = strict_or_fast_and valid, validate_strict_properties(schema, data, errors, path)
      end

      # validation: string
      if data.is_a?(String)
        valid = strict_or_fast_and valid, validate_format(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_max_length(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_min_length(schema, data, errors, path)
        valid = strict_or_fast_and valid, validate_pattern(schema, data, errors, path)
      end

      valid
    end

    def validate_additional_properties(schema, data, errors, path)
      return true if schema.additional_properties == true

      # schema indicates that all properties not in `properties` should be
      # validated according to subschema
      if schema.additional_properties.is_a?(Schema)
        extra = get_extra_keys(schema, data)
        validations = extra.map do |key|
          validate_data(schema.additional_properties, data[key], errors, path + [key])
        end

        # true only if all keys validate
        validations.all?

      # boolean indicates whether additional properties are allowed
      else
        validate_extra(schema, data, errors, path)
      end
    end

    def validate_all_of(schema, data, errors, path)
      return true if schema.all_of.empty?

      # We've kept this feature behind a configuration flag for now because
      # there is some performance implication to producing each sub error.
      # Normally we can short circuit the validation after encountering only
      # one problem, but here we have to evaluate all subschemas every time.
      if JsonSchema.configuration.all_of_sub_errors && !@fail_fast
        sub_errors = []
        valid = schema.all_of.map do |subschema|
          current_sub_errors = []
          sub_errors << current_sub_errors
          validate_data(subschema, data, current_sub_errors, path)
        end.all?
      else
        sub_errors = nil
        valid = schema.all_of.all? do |subschema|
          validate_data(subschema, data, errors, path)
        end
      end

      message = %{Not all subschemas of "allOf" matched.}
      errors << ValidationError.new(schema, path, message, :all_of_failed,
        sub_errors: sub_errors, data: data) if !valid
      valid
    end

    def validate_any_of(schema, data, errors, path)
      return true if schema.any_of.empty?

      sub_errors = schema.any_of.map do |subschema|
        current_sub_errors = []
        valid = catch(:fail_fast) do
          validate_data(subschema, data, current_sub_errors, path)
        end
        return true if valid
        current_sub_errors
      end

      message = %{No subschema in "anyOf" matched.}
      errors << ValidationError.new(schema, path, message, :any_of_failed,
        sub_errors: sub_errors, data: data)

      false
    end

    def validate_dependencies(schema, data, errors, path)
      return true if schema.dependencies.empty?
      result = schema.dependencies.map do |key, obj|
        # if the key is not present, the dependency is fulfilled by definition
        next true unless data[key]
        if obj.is_a?(Schema)
          validate_data(obj, data, errors, path)
        else
          # if not a schema, value is an array of required fields
          validate_required(schema, data, errors, path, obj)
        end
      end
      result.all?
    end

    def validate_format(schema, data, errors, path)
      return true unless schema.format
      validator = (
        JsonSchema.configuration.custom_formats[schema.format] ||
        DEFAULT_FORMAT_VALIDATORS[schema.format]
      )
      if validator[data]
        true
      else
        message = %{#{data} is not a valid #{schema.format}.}
        errors << ValidationError.new(schema, path, message, :invalid_format, data: data)
        false
      end
    end

    def validate_enum(schema, data, errors, path)
      return true unless schema.enum
      if schema.enum.include?(data)
        true
      else
        message = %{#{data} is not a member of #{schema.enum}.}
        errors << ValidationError.new(schema, path, message, :invalid_type, data: data)
        false
      end
    end

    def validate_extra(schema, data, errors, path)
      extra = get_extra_keys(schema, data)
      if extra.empty?
        true
      else

        message = %{"#{extra.sort.join('", "')}" } +
          (extra.length == 1 ? "is not a" : "are not") +
          %{ permitted key} +
          (extra.length == 1 ? "." : "s.")
        errors << ValidationError.new(schema, path, message, :invalid_keys)
        false
      end
    end

    def validate_items(schema, data, errors, path)
      return true unless schema.items
      if schema.items.is_a?(Array)
        if data.size < schema.items.count
          message = %{#{schema.items.count} item} +
            (schema.items.count == 1 ? "" : "s") +
            %{ required; only #{data.size} } +
            (data.size == 1 ? "was" : "were") +
            %{ supplied.}
          errors << ValidationError.new(schema, path, message, :min_items_failed, data: data)
          false
        elsif data.size > schema.items.count && !schema.additional_items?
          message = %{No more than #{schema.items.count} item} +
            (schema.items.count == 1 ? " is" : "s are") +
            %{ allowed; #{data.size} } +
            (data.size > 1 ? "were" : "was") +
            %{ supplied.}
          errors << ValidationError.new(schema, path, message, :max_items_failed, data: data)
          false
        else
          valid = true
          if data.size > schema.items.count && schema.additional_items.is_a?(Schema)
            (schema.items.count..data.count - 1).each do |i|
              valid = strict_or_fast_and valid,
                validate_data(schema.additional_items, data[i], errors, path + [i])
            end
          end
          schema.items.each_with_index do |subschema, i|
            valid = strict_or_fast_and valid,
              validate_data(subschema, data[i], errors, path + [i])
          end
          valid
        end
      else
        valid = true
        data.each_with_index do |value, i|
          valid = strict_or_fast_and valid,
            validate_data(schema.items, value, errors, path + [i])
        end
        valid
      end
    end

    def validate_max(schema, data, errors, path)
      return true unless schema.max
      if schema.max_exclusive? && data < schema.max
        true
      elsif !schema.max_exclusive? && data <= schema.max
        true
      else
        message = %{#{data} must be less than} +
          (schema.max_exclusive? ? "" : " or equal to") +
          %{ #{schema.max}.}
        errors << ValidationError.new(schema, path, message, :max_failed, data: data)
        false
      end
    end

    def validate_max_items(schema, data, errors, path)
      return true unless schema.max_items
      if data.size <= schema.max_items
        true
      else
        message = %{No more than #{schema.max_items} item} +
          (schema.max_items == 1 ? " is" : "s are") +
          %{ allowed; #{data.size} } +
          (data.size == 1 ? "was" : "were")+
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :max_items_failed, data: data)
        false
      end
    end

    def validate_max_length(schema, data, errors, path)
      return true unless schema.max_length
      if data.length <= schema.max_length
        true
      else
        message = %{Only #{schema.max_length} character} +
          (schema.max_length == 1 ? " is" : "s are") +
          %{ allowed; #{data.length} } +
          (data.length == 1 ? "was" : "were") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :max_length_failed, data: data)
        false
      end
    end

    def validate_max_properties(schema, data, errors, path)
      return true unless schema.max_properties
      if data.keys.size <= schema.max_properties
        true
      else
        message = %{No more than #{schema.max_properties} propert} +
          (schema.max_properties == 1 ? "y is" : "ies are") +
          %{ allowed; #{data.keys.size} } +
          (data.keys.size == 1 ? "was" : "were") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :max_properties_failed, data: data)
        false
      end
    end

    def validate_min(schema, data, errors, path)
      return true unless schema.min
      if schema.min_exclusive? && data > schema.min
        true
      elsif !schema.min_exclusive? && data >= schema.min
        true
      else
        message = %{#{data} must be greater than} +
          (schema.min_exclusive? ? "" : " or equal to") +
          %{ #{schema.min}.}
        errors << ValidationError.new(schema, path, message, :min_failed, data: data)
        false
      end
    end

    def validate_min_items(schema, data, errors, path)
      return true unless schema.min_items
      if data.size >= schema.min_items
        true
      else
        message = %{#{schema.min_items} item} +
          (schema.min_items == 1 ? "" : "s") +
          %{ required; only #{data.size} } +
          (data.size == 1 ? "was" : "were") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :min_items_failed, data: data)
        false
      end
    end

    def validate_min_length(schema, data, errors, path)
      return true unless schema.min_length
      if data.length >= schema.min_length
        true
      else
        message = %{At least #{schema.min_length} character} +
          (schema.min_length == 1 ? " is" : "s are") +
          %{ required; only #{data.length} } +
          (data.length == 1 ? "was" : "were") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :min_length_failed, data: data)
        false
      end
    end

    def validate_min_properties(schema, data, errors, path)
      return true unless schema.min_properties
      if data.keys.size >= schema.min_properties
        true
      else
        message = %{At least #{schema.min_properties} propert}+
          (schema.min_properties == 1 ? "y is" : "ies are") +
          %{ required; #{data.keys.size} }+
          (data.keys.size == 1 ? "was" : "were") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :min_properties_failed, data: data)
        false
      end
    end

    def validate_multiple_of(schema, data, errors, path)
      return true unless schema.multiple_of
      if data % schema.multiple_of == 0
        true
      else
        message = %{#{data} is not a multiple of #{schema.multiple_of}.}
        errors << ValidationError.new(schema, path, message, :multiple_of_failed, data: data)
        false
      end
    end

    def validate_one_of(schema, data, errors, path)
      return true if schema.one_of.empty?
      sub_errors = []

      num_valid = schema.one_of.count do |subschema|
        current_sub_errors = []
        valid = catch(:fail_fast) do
          validate_data(subschema, data, current_sub_errors, path)
        end
        sub_errors << current_sub_errors
        valid
      end

      return true if num_valid == 1

      message =
        if num_valid == 0
          %{No subschema in "oneOf" matched.}
        else
          %{More than one subschema in "oneOf" matched.}
        end
      errors << ValidationError.new(schema, path, message, :one_of_failed,
        sub_errors: sub_errors, data: data)

      false
    end

    def validate_not(schema, data, errors, path)
      return true unless schema.not
      # don't bother accumulating these errors, they'll all be worded
      # incorrectly for the inverse condition
      valid = !validate_data(schema.not, data, [], path)
      if !valid
        message = %{Matched "not" subschema.}
        errors << ValidationError.new(schema, path, message, :not_failed, data: data)
      end
      valid
    end

    def validate_pattern(schema, data, errors, path)
      return true unless schema.pattern

      if data =~ schema.pattern
        true
      else
        message = %{#{data} does not match #{schema.pattern.inspect}.}
        errors << ValidationError.new(schema, path, message, :pattern_failed, data: data)
        false
      end
    end

    def validate_pattern_properties(schema, data, errors, path)
      return true if schema.pattern_properties.empty?
      valid = true
      schema.pattern_properties.each do |pattern, subschema|
        data.each do |key, value|
          if key =~ pattern
            valid = strict_or_fast_and valid,
              validate_data(subschema, value, errors, path + [key])
          end
        end
      end
      valid
    end

    def validate_properties(schema, data, errors, path)
      return true if schema.properties.empty?
      valid = true
      schema.properties.each do |key, subschema|
        next unless data.key?(key)
        valid = strict_or_fast_and valid,
          validate_data(subschema, data[key], errors, path + [key])
      end
      valid
    end

    def validate_required(schema, data, errors, path, required)
      return true if !required || required.empty?
      if (missing = required - data.keys).empty?
        true
      else
        message = %{"#{missing.sort.join('", "')}" } +
          (missing.length == 1 ? "wasn't" : "weren't") +
          %{ supplied.}
        errors << ValidationError.new(schema, path, message, :required_failed, data: missing)
        false
      end
    end

    def validate_strict_properties(schema, data, errors, path)
      return true if !schema.strict_properties

      strict_or_fast_and validate_extra(schema, data, errors, path),
        validate_required(schema, data, errors, path, schema.properties.keys)
    end

    def validate_type(schema, data, errors, path)
      return true if !schema.type || schema.type.empty?
      if schema.type_parsed.any? { |t| data.is_a?(t) }
        true
      else
        key = find_parent(schema)
        message = %{For '#{key}', #{data.inspect} is not #{ErrorFormatter.to_list(schema.type)}.}
        errors << ValidationError.new(schema, path, message, :invalid_type, data: data)
        false
      end
    end

    def validate_unique_items(schema, data, errors, path)
      return true unless schema.unique_items?
      if data.size == data.uniq.size
        true
      else
        message = %{Duplicate items are not allowed.}
        errors << ValidationError.new(schema, path, message, :unique_items_failed, data: data)
        false
      end
    end

    def find_parent(schema)
      fragment = schema.fragment
      key = if fragment =~ /patternProperties/
              split_pointer = schema.pointer.split("/")
              idx = split_pointer.index("patternProperties")

              # this join mimics the fragment format below in that it's
              # parent + key
              if idx - 2 >= 0
                parts = split_pointer[(idx - 2)..(idx - 1)]
              end

              # protect against a `nil` that could occur if
              # `patternProperties` has no parent
              parts ? parts.compact.join("/") : nil
            end
      key || fragment
    end

    DEFAULT_FORMAT_VALIDATORS = {
      "date" => ->(data) { data =~ DATE_PATTERN },
      "date-time" => ->(data) { data =~ DATE_TIME_PATTERN },
      "email" => ->(data) { data =~ EMAIL_PATTERN },
      "hostname" => ->(data) { data =~ HOSTNAME_PATTERN },
      "ipv4" => ->(data) { data =~ IPV4_PATTERN },
      "ipv6" => ->(data) { data =~ IPV6_PATTERN },
      "regex" => ->(data) { Regexp.new(data) rescue false },
      "uri" => ->(data) { URI.parse(data) rescue false },

      # From the spec: a string instance is valid URI Reference (either a URI
      # or a relative-reference), according to RFC3986.
      #
      # URI.parse will a handle a relative reference as well as an absolute
      # one. Really though we should try to make "uri" more restrictive, and
      # both of these could do to be more robust.
      "uri-reference" => ->(data) { URI.parse(data) rescue false },

      "uuid" => ->(data) { data =~ UUID_PATTERN },
    }.freeze

    EMAIL_PATTERN = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]+$/i

    HOSTNAME_PATTERN = /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/

    DATE_PATTERN = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/

    DATE_TIME_PATTERN = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-2][0-9]:[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|[\-+][0-9]{2}:[0-5][0-9])$/

    # from: http://stackoverflow.com/a/17871737
    IPV4_PATTERN = /^((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])$/

    # from: http://stackoverflow.com/a/17871737
    IPV6_PATTERN = /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]).){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:)$/

    UUID_PATTERN = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/
  end
end
