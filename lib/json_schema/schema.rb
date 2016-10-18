require "json"

module JsonSchema
  class Schema
    include Attributes

    def initialize
      # nil out all our fields so that it's possible to instantiate a schema
      # instance without going through the parser and validate against it
      # without Ruby throwing warnings about uninitialized instance variables.
      initialize_attrs
    end

    # Fragment of a JSON Pointer that can help us build a pointer back to this
    # schema for debugging.
    attr_accessor :fragment

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
    attr_schema :id

    # Short title of the schema (or the hyper-schema link if this is one).
    #
    # Type: String
    attr_schema :title

    # More detailed description of the schema (or the hyper-schema link if this
    # is one).
    #
    # Type: String
    attr_schema :description

    # Default JSON value for this particular schema
    #
    # Type: [any]
    attr_schema :default

    #
    # Validation: Any
    #

    # A collection of subschemas of which data must validate against the full
    # set of to be valid.
    #
    # Type: Array[Schema]
    attr_schema :all_of, :schema_name => :allOf

    # A collection of subschemas of which data must validate against any schema
    # in the set to be be valid.
    #
    # Type: Array[Schema]
    attr_schema :any_of, :schema_name => :anyOf

    # A collection of inlined subschemas. Standard convention is to subschemas
    # here and reference them from elsewhere.
    #
    # Type: Hash[String => Schema]
    attr_schema :definitions

    # A collection of objects that must include the data for it to be valid.
    #
    # Type: Array
    attr_schema :enum

    # A collection of subschemas of which data must validate against exactly
    # one of to be valid.
    #
    # Type: Array[Schema]
    attr_schema :one_of, :schema_name => :oneOf

    # A subschema which data must not validate against to be valid.
    #
    # Type: Schema
    attr_schema :not

    # An array of types that data is allowed to be. The spec allows this to be
    # a string as well, but the parser will always normalize this to an array
    # of strings.
    #
    # Type: Array[String]
    attr_schema :type

    # validation: array
    attr_schema :additional_items, :schema_name => :additionalItems
    attr_schema :items
    attr_schema :max_items, :schema_name => :maxItems
    attr_schema :min_items, :schema_name => :minItems
    attr_schema :unique_items, :schema_name => :uniqueItems

    # validation: number/integer
    attr_schema :max
    attr_schema :max_exclusive, :schema_name => :maxExclusive
    attr_schema :min
    attr_schema :min_exclusive, :schema_name => :minExclusive
    attr_schema :multiple_of, :schema_name => :multipleOf

    # validation: object
    attr_schema :additional_properties, :schema_name => :additionalProperties
    attr_schema :dependencies
    attr_schema :max_properties, :schema_name => :maxProperties
    attr_schema :min_properties, :schema_name => :minProperties
    attr_schema :pattern_properties, :schema_name => :patternProperties
    attr_schema :properties
    attr_schema :required
    # warning: strictProperties is technically V5 spec (but I needed it now)
    attr_schema :strict_properties, :schema_name => :strictProperties

    # validation: string
    attr_schema :format
    attr_schema :max_length, :schema_name => :maxLength
    attr_schema :min_length, :schema_name => :minLength
    attr_schema :pattern

    # hyperschema
    attr_schema :links
    attr_schema :media
    attr_schema :path_start, :schema_name => :pathStart
    attr_schema :read_only, :schema_name => :readOnly

    # hyperschema link attributes
    attr_schema :enc_type
    attr_schema :href
    attr_schema :media_type
    attr_schema :method
    attr_schema :rel
    attr_schema :schema
    attr_schema :target_schema

    # Give these properties reader defaults for particular behavior so that we
    # can preserve the `nil` nature of their instance variables. Knowing that
    # these were `nil` when we read them allows us to properly reflect the
    # parsed schema back to JSON.
    attr_reader_default :additional_items, true
    attr_reader_default :additional_properties, true
    attr_reader_default :all_of, []
    attr_reader_default :any_of, []
    attr_reader_default :clones, Set.new
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

    attr_reader_default :enc_type, "application/json"
    attr_reader_default :media_type, "application/json"

    # allow booleans to be access with question mark
    alias :additional_items? :additional_items
    alias :expanded? :expanded
    alias :max_exclusive? :max_exclusive
    alias :min_exclusive? :min_exclusive
    alias :read_only? :read_only
    alias :unique_items? :unique_items

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
        self.class.copyable_attrs.each do |copyable|
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

    def validate(data)
      validator = Validator.new(self)
      valid = validator.validate(data)
      [valid, validator.errors]
    end

    def validate!(data)
      Validator.new(self).validate!(data)
    end

    # Link subobject for a hyperschema.
    class Link < Schema
      inherit_attrs
    end

    # Media type subobject for a hyperschema.
    class Media
      attr_accessor :binary_encoding
      attr_accessor :type
    end
  end
end
