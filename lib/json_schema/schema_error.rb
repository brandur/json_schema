module JsonSchema
  class SchemaError
    attr_accessor :message, :schema, :type

    def self.aggregate(errors)
      errors.map(&:to_s)
    end

    # make `type` required on the next major version bump
    def initialize(schema, message, type = nil)
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

    # make `type` required on the next major version bump
    def initialize(schema, path, message, type = nil)
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
end
