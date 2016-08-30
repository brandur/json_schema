require "uri"
require_relative "json_pointer"

module JsonReference
  def self.reference(ref)
    Reference.new(ref)
  end

  class Reference
    include Comparable

    attr_accessor :pointer
    attr_accessor :uri

    def initialize(ref)
      # Note that the #to_s of `nil` is an empty string.
      @uri = nil

      # given a simple fragment without '#', resolve as a JSON Pointer only as
      # per spec
      if ref.include?("#")
        uri, @pointer = ref.split('#')
        if uri && !uri.empty?
          @uri = URI.parse(uri)
        end
        @pointer ||= ""
      else
        @pointer = ref
      end

      # normalize pointers by prepending "#" and stripping trailing "/"
      @pointer = "#" + @pointer
      @pointer = @pointer.chomp("/")
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def inspect
      "\#<JsonReference::Reference #{to_s}>"
    end

    # Given the document addressed by #uri, resolves the JSON Pointer part of
    # the reference.
    def resolve_pointer(data)
      JsonPointer.evaluate(data, @pointer)
    end

    def to_s
      if @uri
        "#{@uri.to_s}#{@pointer}"
      else
        @pointer
      end
    end
  end
end
