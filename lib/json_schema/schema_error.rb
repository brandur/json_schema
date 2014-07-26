module JsonSchema
  class SchemaError
    attr_accessor :message
    attr_accessor :schema

    def self.aggregate(errors)
      errors.map(&:to_s)
    end

    def initialize(schema, message)
      @schema = schema
      @message = message
    end

    def to_s
      "#{schema.pointer}: #{message}"
    end
  end

  class ValidationError < SchemaError
    attr_accessor :path

    def initialize(schema, path, message)
      super(schema, message)
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
