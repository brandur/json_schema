module JsonCommon
  # Attributes mixes in some useful attribute-related methods for use in
  # defining schema classes in a spirit similar to Ruby's attr_accessor and
  # friends.
  module Attributes
    # Provides class-level methods for the Attributes module.
    module ClassMethods
      attr_reader :copyable_aliases

      # Attributes that should be copied between classes when invoking
      # Attributes#copy_from.
      #
      # Hash contains instance variable names mapped to a default value for the
      # field.
      attr_reader :copyable_attrs

      # Attributes that are part of the JSON schema and hyper-schema
      # specifications. These are allowed to be accessed with the [] operator.
      #
      # Hash contains the access key mapped to the name of the method that should
      # be invoked to retrieve a value. For example, `type` maps to `type` and
      # `additionalItems` maps to `additional_items`.
      attr_reader :schema_attrs

      def alias_copyable(dest, source)
        self.class.define_singleton_method(dest) do
          send(source)
        end

        self.copyable_aliases << dest
      end

      # identical to attr_accessible, but allows us to copy in values from a
      # target schema to help preserve our hierarchy during reference expansion
      def attr_copyable(attr, options = {})
        attr_accessor(attr)

        # Usually the default being assigned here is nil.
        self.copyable_attrs["@#{attr}".to_sym] = options[:default]

        if default = options[:default]
          # remove the reader already created by attr_accessor
          remove_method(attr)

          define_method(attr) do
            val = instance_variable_get(:"@#{attr}")
            if !val.nil?
              val
            else
              if [Array, Hash, Set].include?(default.class)
                default.dup
              else
                default
              end
            end
          end
        end
      end

      def attr_schema(attr, options = {})
        attr_copyable(attr, :default => options[:default])
        self.schema_attrs[options[:schema_name] || attr] = attr
      end

      # Directive indicating that attributes should be inherited from a parent
      # class.
      #
      # Must appear as first statement in class that mixes in (or whose parent
      # mixes in) the Attributes module.
      def inherit_attrs
        @copyable_attrs = self.superclass.instance_variable_get(:@copyable_attrs).dup
        @schema_attrs = self.superclass.instance_variable_get(:@schema_attrs).dup
      end

      # Initializes some class instance variables required to make other
      # methods in the Attributes module work. Run automatically when the
      # module is mixed into another class.
      def initialize_attrs
        @copyable_aliases = []
        @copyable_attrs = {}
        @schema_attrs = {}
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.send(:initialize_attrs)
    end

    # Allows the values of schema attributes to be accessed with a symbol or a
    # string. So for example, the value of `schema.additional_items` could be
    # procured with `schema[:additionalItems]`. This only works for attributes
    # that are part of the JSON schema specification; other methods on the
    # class are not available (e.g. `expanded`.)
    #
    # This is implemented so that `JsonPointer::Evaluator` can evaluate a
    # reference on an sintance of this class (as well as plain JSON data).
    def [](name)
      name = name.to_sym
      if self.class.schema_attrs.key?(name)
        send(self.class.schema_attrs[name])
      else
        raise NoMethodError, "Schema does not respond to ##{name}"
      end
    end

    def copy_aliases_ref
      @copy_aliases_ref
    end

    # This value only set if this object was hydrated from another copyable
    # object using #copy_from.
    def copy_attrs_ref
      @copy_attrs_ref
    end

    def copy_from(schema)
      @copy_attrs_ref = schema.copy_attrs_ref || schema.class.copyable_attrs
      @copy_attrs_ref.each do |attr, default|
        # proxy this value back to original schema
        attr = attr[1..-1].to_sym # strips "@"
        self.define_singleton_method(attr) do
          schema.send(attr)
        end
      end

      @copy_aliases_ref = schema.copy_aliases_ref || schema.class.copyable_aliases
      @copy_aliases_ref.each do |name|
        self.define_singleton_method(name) do
          schema.send(name)
        end
      end
    end

    def initialize_attrs
      self.class.copyable_attrs.each do |attr, _|
        instance_variable_set(attr, nil)
      end
    end
  end
end
