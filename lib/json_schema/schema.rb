require "json"

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

    def initialize
      @clones = Set.new
    end

    # Fragment of a JSON Pointer that can help us build a pointer back to this
    # schema for debugging.
    attr_accessor :fragment

    # An array that represents the nested path of the final JSON Pointer.
    attr_accessor :split_pointer

    # Rather than a normal schema, the node may be a JSON Reference. In this
    # case, no other attributes will be filled in except for #parent.
    attr_accessor :reference

    attr_copyable :expanded

    # A reference to the data which the Schema was initialized from. Used for
    # resolving JSON Pointer references.
    #
    # Type: Hash
    attr_copyable :data

    #
    # Relations
    #

    # Parent Schema object. Child may come from any of `definitions`,
    # `properties`, `anyOf`, etc.
    #
    # Type: Schema
    attr_copyable :parent

    # Collection of clones of this schema object, meaning all Schemas that were
    # initialized after the original. Used for JSON Reference expansion. The
    # only copy not present in this set is the original Schema object.
    #
    # Type: Set[Schema]
    attr_copyable :clones

    # The normalized URI of this schema. Note that child schemas inherit a URI
    # from their parent unless they have one explicitly defined, so this is
    # likely not a unique value in any given schema hierarchy.
    #
    # Type: String
    attr_copyable :uri

    #
    # Metadata
    #

    # Alters resolution scope. This value is used along with the parent scope's
    # URI to build a new address for this schema. Relative ID's will append to
    # the parent, and absolute URI's will replace it.
    #
    # Type: String
    attr_copyable :id

    # Short title of the schema.
    #
    # Type: String
    attr_copyable :title

    # More detailed description of the schema.
    #
    # Type: String
    attr_copyable :description

    # Default JSON value for this particular schema
    #
    # Type: [any]
    attr_copyable :default

    #
    # Validation: Any
    #

    # A collection of subschemas of which data must validate against the full
    # set of to be valid.
    #
    # Type: Array[Schema]
    attr_copyable :all_of

    # A collection of subschemas of which data must validate against any schema
    # in the set to be be valid.
    #
    # Type: Array[Schema]
    attr_copyable :any_of

    # A collection of inlined subschemas. Standard convention is to subschemas
    # here and reference them from elsewhere.
    #
    # Type: Hash[String => Schema]
    attr_copyable :definitions

    # A collection of objects that must include the data for it to be valid.
    #
    # Type: Array
    attr_copyable :enum

    # A collection of subschemas of which data must validate against exactly
    # one of to be valid.
    #
    # Type: Array[Schema]
    attr_copyable :one_of

    # A subschema which data must not validate against to be valid.
    #
    # Type: Schema
    attr_copyable :not

    # An array of types that data is allowed to be. The spec allows this to be
    # a string as well, but the parser will always normalize this to an array
    # of strings.
    #
    # Type: Array[String]
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
    # warning: strictProperties is technically V5 spec (but I needed it now)
    attr_copyable :strict_properties

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
    attr_reader_default :strict_properties, false
    attr_reader_default :type, []

    # allow booleans to be access with question mark
    alias :additional_items? :additional_items
    alias :expanded? :expanded
    alias :max_exclusive? :max_exclusive
    alias :min_exclusive? :min_exclusive
    alias :read_only? :read_only
    alias :unique_items? :unique_items

    def copy_from(schema)
      @@copyable.each do |copyable|
        instance_variable_set(copyable, schema.instance_variable_get(copyable))
      end
    end

    def expand_references(options = {})
      expander = ReferenceExpander.new
      if expander.expand(self, options)
        [true, nil]
      else
        [false, expander.errors]
      end
    end

    def expand_references!(options = {})
      ReferenceExpander.new.expand!(self, options)
      true
    end

    def inspect
      "\#<JsonSchema::Schema pointer=#{pointer}>"
    end

    def inspect_schema
      if reference
        str = reference.to_s
        str += expanded? ? " [EXPANDED]" : " [COLLAPSED]"
        str += original? ? " [ORIGINAL]" : " [CLONE]"
        str
      else
        hash = {}
        @@copyable.each do |copyable|
          next if [:@clones, :@data, :@parent, :@uri].include?(copyable)
          if value = instance_variable_get(copyable)
            if value.is_a?(Array)
              if !value.empty?
                hash[copyable] = value.map { |v| inspect_value(v) }
              end
            elsif value.is_a?(Hash)
              if !value.empty?
                hash[copyable] =
                  Hash[*value.map { |k, v| [k, inspect_value(v)] }.flatten]
              end
            else
              hash[copyable] = inspect_value(value)
            end
          end
        end
        hash
      end
    end

    def inspect_value(value)
      if value.is_a?(Schema)
        value.inspect_schema
      else
        value.inspect
      end
    end

    def original?
      !clones.include?(self)
    end

    def pointer
      if parent
        parent.pointer + "/" + fragment
      else
        fragment
      end
    end

    def split_pointer
      @split_pointer ||= pointer.split("/")
    end

    def validate(data)
      validator = Validator.new(self)
      valid = validator.validate(data)
      [valid, validator.errors]
    end

    def validate!(data)
      Validator.new(self).validate!(data)
    end

    # Link subobject for a hyperschema.
    class Link
      attr_accessor :parent

      # schema attributes
      attr_accessor :description
      attr_accessor :enc_type
      attr_accessor :href
      attr_accessor :method
      attr_accessor :rel
      attr_accessor :media_type
      attr_accessor :schema
      attr_accessor :target_schema
      attr_accessor :title

      def enc_type
        @enc_type || "application/json"
      end

      def media_type
        @media_type || "application/json"
      end
    end

    # Media type subobject for a hyperschema.
    class Media
      attr_accessor :binary_encoding
      attr_accessor :type
    end
  end
end
