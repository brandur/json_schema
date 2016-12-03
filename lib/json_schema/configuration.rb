module JsonSchema
  class Configuration
    attr_accessor :all_of_sub_errors
    attr_reader :custom_formats
    attr_reader :validate_regex_with

    def validate_regex_with=(validator)
      @validate_regex_with = validator
    end

    def register_format(name, validator_proc)
      @custom_formats[name] = validator_proc
    end

    # Used for testing.
    def reset!
      @validate_regex_with = nil
      @custom_formats = {}
      @all_of_sub_errors = false
    end

    private

    def initialize
      reset!
    end
  end
end
