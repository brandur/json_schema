module JsonSchema
  class Error < RuntimeError
  end

  class AggregateError < Error
    attr_accessor :errors

    def initialize(errors)
      @errors = errors
    end

    def to_s
      @errors.join(" ")
    end
  end

  class SchemaError < Error
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
      if schema && schema.pointer
        "#{schema.pointer}: #{message}"
      else
        message
      end
    end
  end

  class ValidationError < SchemaError
    attr_accessor :data, :path, :sub_errors

    def initialize(schema, path, message, type, options = {})
      super(schema, message, type)
      @path = path

      # TODO: change to named optional arguments when Ruby 1.9 support is
      # removed
      @data = options[:data]
      @sub_errors = options[:sub_errors]
    end

    def pointer
      path.join("/")
    end

    def to_s
      "#{pointer}: failed schema #{schema.pointer}: #{message}"
    end
  end

  module ErrorFormatter
    def to_list(list)
      words_connector     = ', '
      two_words_connector = ' or '
      last_word_connector = ', or '

      length = list.length
      joined_list = case length
                    when 1
                      list[0]
                    when 2
                      "#{list[0]}#{two_words_connector}#{list[1]}"
                     else
                      "#{list[0...-1].join(words_connector)}#{last_word_connector}#{list[-1]}"
                    end

      if joined_list[0] =~ /^[aeiou]/
        "an #{joined_list}"
      else
        "a #{joined_list}"
      end
    end
    module_function :to_list
  end
end
