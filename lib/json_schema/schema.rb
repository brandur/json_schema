module JsonSchema
  class Schema
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

      @uri = "/"
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
  end
end
