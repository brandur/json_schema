module JsonSchema
  class Configuration
    attr_reader :validate_regex_with

    def validate_regex_with=(validator)
      @validate_regex_with = validator
    end

    private

    def initialize
      @validate_regex_with = nil
    end

  end
end
