require "uri"
require_relative "json_common/attributes"
require_relative "json_pointer"

module JsonReference
  def self.reference(ref)
    Reference.new(ref)
  end

  class Reference
    include Comparable
    include JsonCommon::Attributes

    # Collection of clones of this schema object, meaning all Schemas that were
    # initialized after the original. Used for JSON Reference expansion. The
    # only copy not present in this set is the original Schema object.
    #
    # Note that this doesn't have a default option because we rely on the fact
    # that the set is the *same object* between all clones of any given schema.
    #
    # Type: Set[Schema]
    attr_copyable :clones

    attr_accessor :expanded
    alias :expanded? :expanded

    attr_accessor :fragment

    # Fragment of a JSON Pointer that can help us build a pointer back to this
    # schema for debugging.

    # Parent Schema object. Child may come from any of `definitions`,
    # `properties`, `anyOf`, etc.
    #
    # Type: Schema
    attr_copyable :parent

    attr_accessor :pointer
    attr_accessor :uri

    def initialize(ref)
      # Note that the #to_s of `nil` is an empty string.
      @uri = nil

      # Always started out now expanded.
      @expanded = false

      # Don't put this in as an attribute default. We require that this precise
      # pointer gets copied between all clones of any given schema so that they
      # all share exactly the same set.
      @clones = Set.new

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

    def original?
      !clones.include?(self)
    end

    def reference?
      true
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
