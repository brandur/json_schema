module JsonSchema
  class SchemaError
    attr_accessor :message
    attr_accessor :schema

    def self.aggregate(errors)
      errors.map { |e|
        if e.schema
          %{#{e.schema.pointer}: #{e.message}}
        else
          e.message
        end
      }.join(" ")
    end

    def initialize(schema, message)
      @schema = schema
      @message = message
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
  end
end
