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
    attr_accessor :definitions_children
    attr_accessor :properties_children

    # the normalize URI of this schema
    attr_accessor :uri

    def initialize
      @type = []

      @definitions_children = []
      @properties_children = []
    end

    # child schemas of all types
    def children
      Enumerator.new do |yielder|
        definitions_children.each do |c|
          yielder << c
        end
        properties_children.each do |c|
          yielder << c
        end
      end
    end

    def expand_references!
      ReferenceExpander.new(self).expand
    end

    # @todo: get rid of this thing; terrible
    def replace_reference(ref, new)
      if definitions_children.select { |s| s.reference == ref }
        definitions_children.delete_if { |s| s.reference == ref }
        definitions_children << new
      end

      if properties_children.select { |s| s.reference == ref }
        properties_children.delete_if { |s| s.reference == ref }
        properties_children << new
      end
    end
  end
end
