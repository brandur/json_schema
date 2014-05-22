module JsonSchema
  class SchemaError
    attr_accessor :message
    attr_accessor :schema

    def self.aggregate(errors)
      # May want to eventually use a JSON Pointer instead to help user narrow
      # down the location of the error. It's slightly tricky to ascend the
      # schema hierarchy to raise build one though, so I'm punting on that
      # for now.
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
