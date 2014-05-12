module JsonSchema
  class Schema
    @@copyable = []

    # identical to attr_accessible, but allows us to copy in values from a
    # target schema to help preserve our hierarchy during reference expansion
    def self.attr_copyable(attr)
      attr_accessor(attr)
      @@copyable << "@#{attr}".to_sym
    end

    # Rather than a normal schema, the node may be a JSON Reference. In this
    # case, no other attributes will be filled in except for #parent.
    attr_copyable :reference

    # the schema keeps a reference to the data it was initialized from for JSON
    # Pointer resolution
    attr_copyable :data

    # basic descriptors
    attr_copyable :id
    attr_copyable :title
    attr_copyable :description

    # parent and children schemas
    attr_copyable :parent

    # map of name --> schema
    attr_copyable :definitions

    # map of name --> schema
    attr_copyable :properties

    # the normalize URI of this schema
    attr_copyable :uri

    # validation: all
    attr_copyable :enum
    # Types assigned to this schema. Always an array/union type no matter what
    # was defined in the original schema.
    attr_copyable :type

    # validation: array
    attr_copyable :max_items
    attr_copyable :min_items
    attr_copyable :unique_items

    # validation: number/integer
    attr_copyable :max
    attr_copyable :max_exclusive
    attr_copyable :min
    attr_copyable :min_exclusive
    attr_copyable :multiple_of

    # validation: object
    attr_copyable :additional_properties
    attr_copyable :dependencies
    attr_copyable :max_properties
    attr_copyable :min_properties
    attr_copyable :pattern_properties
    attr_copyable :required

    # validation: schema
    attr_copyable :all_of
    attr_copyable :any_of
    attr_copyable :one_of
    attr_copyable :not

    # validation: string
    attr_copyable :max_length
    attr_copyable :min_length
    attr_copyable :pattern

    # hyperschema
    attr_copyable :links

    def initialize
      @type = []

      # these are all the subschema types; default them to empty data
      # structures for simplified iteration
      @all_of = []
      @any_of = []
      @one_of = []
      @definitions = {}
      @dependencies = {}
      @pattern_properties = {}
      @properties = {}
    end

    def additional_properties
      !@additional_properties.nil? ? @additional_properties : true
    end

    def max_exclusive
      !@max_exclusive.nil? ? @max_exclusive : false
    end

    def min_exclusive
      !@min_exclusive.nil? ? @min_exclusive : false
    end

    # child schemas of all types
    def children
      Enumerator.new do |yielder|
        all_of.each { |s| yielder << s }
        any_of.each { |s| yielder << s }
        one_of.each { |s| yielder << s }
        definitions.each { |_, s| yielder << s }
        pattern_properties.each { |_, s| yielder << s }
        properties.each { |_, s| yielder << s }
        yielder << self.not if self.not

        # dependencies can either be simple or "schema"; only replace the
        # latter
        dependencies.values.
          select { |s| s.is_a?(Schema) }.
          each { |s| yielder << s }
      end
    end

    def copy_from(schema)
      @@copyable.each do |copyable|
        instance_variable_set(copyable, schema.instance_variable_get(copyable))
      end
    end

    def expand_references!
      ReferenceExpander.new(self).expand!
      # return self for convenience
      self
    end

    def validate!(data)
      Validator.new(self).validate!(data)
    end
  end
end
