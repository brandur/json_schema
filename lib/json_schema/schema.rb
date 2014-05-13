module JsonSchema
  class Schema
    @@copyable = []

    # identical to attr_accessible, but allows us to copy in values from a
    # target schema to help preserve our hierarchy during reference expansion
    def self.attr_copyable(attr)
      attr_accessor(attr)
      @@copyable << "@#{attr}".to_sym
    end

    def self.attr_reader_default(attr, default)
      class_eval("def #{attr} ; !@#{attr}.nil? ? @#{attr} : #{default} ; end")
    end

    # Rather than a normal schema, the node may be a JSON Reference. In this
    # case, no other attributes will be filled in except for #parent.
    attr_copyable :reference

    # the schema keeps a reference to the data it was initialized from for JSON
    # Pointer resolution
    attr_copyable :data

    # parent and children schemas
    attr_copyable :parent

    # the normalize URI of this schema
    attr_copyable :uri

    # basic descriptors
    attr_copyable :id
    attr_copyable :title
    attr_copyable :description
    attr_copyable :default

    # validation: any
    attr_copyable :all_of
    attr_copyable :any_of
    attr_copyable :definitions
    attr_copyable :enum
    attr_copyable :one_of
    attr_copyable :not
    attr_copyable :type

    # validation: array
    attr_copyable :additional_items
    attr_copyable :items
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
    attr_copyable :properties
    attr_copyable :required

    # validation: string
    attr_copyable :format
    attr_copyable :max_length
    attr_copyable :min_length
    attr_copyable :pattern

    # hyperschema
    attr_copyable :links
    attr_copyable :media
    attr_copyable :path_start
    attr_copyable :read_only

    # allow booleans to be access with question mark
    alias :additional_items? :additional_items
    alias :additional_properties? :additional_properties
    alias :max_exclusive? :max_exclusive
    alias :min_exclusive? :min_exclusive
    alias :read_only? :read_only
    alias :unique_items? :unique_items

    # Give these properties reader defaults for particular behavior so that we
    # can preserve the `nil` nature of their instance variables. Knowing that
    # these were `nil` when we read them allows us to properly reflect the
    # parsed schema back to JSON.
    attr_reader_default :additional_items, true
    attr_reader_default :additional_properties, true
    attr_reader_default :all_of, []
    attr_reader_default :any_of, []
    attr_reader_default :definitions, {}
    attr_reader_default :dependencies, {}
    attr_reader_default :links, []
    attr_reader_default :one_of, []
    attr_reader_default :max_exclusive, false
    attr_reader_default :min_exclusive, false
    attr_reader_default :pattern_properties, {}
    attr_reader_default :properties, {}
    attr_reader_default :type, []

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

    # Link subobject for a hyperschema.
    class Link
      attr_accessor :description
      attr_accessor :href
      attr_accessor :method
      attr_accessor :rel
      attr_accessor :schema
      attr_accessor :title
    end

    # Media type subobject for a hyperschema.
    class Media
      attr_accessor :binary_encoding
      attr_accessor :type
    end
  end
end
