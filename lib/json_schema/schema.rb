module JsonSchema
  class Schema
    # Rather than a normal schema, the node may be a JSON Reference. In this
    # case, no other attributes will be filled in except for #parent.
    attr_accessor :reference

    # the schema keeps a reference to the data it was initialized from for JSON
    # Pointer resolution
    attr_accessor :data

    # basic descriptors
    attr_accessor :id
    attr_accessor :title
    attr_accessor :description

    # Types assigned to this schema. Always an array/union type no matter what
    # was defined in the original schema (defaults to `["any"]`).
    attr_accessor :type

    # parent and children schemas
    attr_accessor :parent

    # map of name --> schema
    attr_accessor :definitions

    # map of name --> schema
    attr_accessor :properties

    # the normalize URI of this schema
    attr_accessor :uri

    # validation: array
    attr_accessor :max_items
    attr_accessor :min_items
    attr_accessor :unique_items

    # validation: number/integer
    attr_accessor :max
    attr_accessor :max_exclusive
    attr_accessor :min
    attr_accessor :min_exclusive
    attr_accessor :multiple_of

    # validation: object
    attr_accessor :additional_properties
    attr_accessor :dependencies
    attr_accessor :max_properties
    attr_accessor :min_properties
    attr_accessor :pattern_properties
    attr_accessor :required

    # validation: schema
    attr_accessor :all_of
    attr_accessor :any_of
    attr_accessor :one_of
    attr_accessor :not

    # validation: string
    attr_accessor :max_length
    attr_accessor :min_length
    attr_accessor :pattern

    def initialize
      @type = []

      @definitions = {}
      @properties = {}
    end

    # child schemas of all types
    def children
      Enumerator.new do |yielder|
        definitions.each do |key, schema|
          yielder << [key, schema]
        end
        properties.each do |key, schema|
          yielder << [key, schema]
        end
      end
    end

    def expand_references!
      ReferenceExpander.new(self).expand
      # return self for convenience
      self
    end
  end
end
