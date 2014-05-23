require "set"

module JsonSchema
  class ReferenceExpander
    attr_accessor :errors

    def expand(schema, options = {})
      @errors = []
      @schema = schema
      @store  = options[:store] ||= DocumentStore.new

      @store.add_uri_reference("/", schema)

      traverse_schema(schema)

      refs = unresolved_refs(schema).sort
      if refs.count > 0
        message = %{Couldn't resolve references: #{refs.to_a.join(", ")}.}
        @errors << SchemaError.new(schema, message)
      end

      @errors.count == 0
    end

    def expand!(schema)
      if !expand(schema)
        raise SchemaError.aggregate(@errors).join(" ")
      end
      true
    end

    private

    def dereference(ref_schema, ref_stack)
      ref = ref_schema.reference

      # detects a reference cycle
      if ref_stack.include?(ref)
        message = %{Reference cycle detected: #{ref_stack.sort.join(", ")}.}
        @errors << SchemaError.new(ref_schema, message)
        return false
      end

      new_schema = resolve_reference(ref_schema)
      return false unless new_schema

      # if the reference resolved to a new reference we need to continue
      # dereferencing until we either hit a non-reference schema, or a
      # reference which is already resolved
      if new_schema.reference && !new_schema.expanded?
        success = dereference(new_schema, ref_stack + [ref])
        return false unless success
      end

      # copy new schema into existing one while preserving parent, fragment,
      # and reference
      parent = ref_schema.parent
      ref_schema.copy_from(new_schema)
      ref_schema.parent = parent

      # correct all parent references to point back to ref_schema instead of
      # new_schema
      if ref_schema.original?
        schema_children(ref_schema).each do |schema|
          schema.parent = ref_schema
        end
      end

      true
    end

    def resolve_pointer(ref_schema, uri_path, resolved_schema)
      ref = ref_schema.reference

      # we've already evaluated this precise URI/pointer combination before
      if !(new_schema = @store.lookup_pointer(uri_path, ref.pointer.to_s))
        data = JsonPointer.evaluate(resolved_schema.data, ref.pointer)

        # couldn't resolve pointer within known schema; that's an error
        if data.nil?
          message = %{Couldn't resolve pointer "#{ref.pointer}".}
          @errors << SchemaError.new(resolved_schema, message)
          return
        end

        # parse a new schema and use the same parent node
        new_schema = Parser.new.parse(data, ref_schema.parent)

        # add the reference into our document store right away; it will
        # eventually be fully expanded
        @store.add_pointer_reference(uri_path, ref.pointer.to_s, new_schema)
      else
        # insert a clone record so that the expander knows to expand it when
        # the schema traversal is finished
        new_schema.clones << ref_schema
      end

      new_schema
    end

    def resolve_reference(ref_schema)
      ref = ref_schema.reference
      uri = ref.uri

      if uri && uri.host
        scheme = uri.scheme || "http"
        # allow resolution if something we've already parsed has claimed the
        # full URL
        if @store.lookup_uri(uri.to_s)
          resolve_uri(ref_schema, uri.to_s)
        else
          message =
            %{Reference resolution over #{scheme} is not currently supported.}
          @errors << SchemaError.new(ref_schema, message)
          nil
        end
      # absolute
      elsif uri && uri.path[0] == "/"
        resolve_uri(ref_schema, uri.path)
      # relative
      elsif uri
        # build an absolute path using the URI of the current schema
        schema_uri = ref_schema.uri.chomp("/")
        resolve_uri(ref_schema, schema_uri + "/" + uri.path)
      # just a JSON Pointer -- resolve against schema root
      else
        resolve_pointer(ref_schema, "/", @schema)
      end
    end

    def resolve_uri(ref_schema, uri_path)
      if schema = @store.lookup_uri(uri_path)
        resolve_pointer(ref_schema, uri_path, schema)
      else
        message = %{Couldn't resolve URI: #{uri_path}.}
        @errors << SchemaError.new(ref_schema, message)
        nil
      end
    end

    def schema_children(schema)
      Enumerator.new do |yielder|
        schema.all_of.each { |s| yielder << s }
        schema.any_of.each { |s| yielder << s }
        schema.one_of.each { |s| yielder << s }
        schema.definitions.each { |_, s| yielder << s }
        schema.pattern_properties.each { |_, s| yielder << s }
        schema.properties.each { |_, s| yielder << s }

        if additional = schema.additional_properties
          if additional.is_a?(Schema)
            yielder << additional
          end
        end

        if schema.not
          yielder << schema.not
        end

        # can either be a single schema (list validation) or multiple (tuple
        # validation)
        if items = schema.items
          if items.is_a?(Array)
            items.each { |s| yielder << s }
          else
            yielder << items
          end
        end

        # dependencies can either be simple or "schema"; only replace the
        # latter
        schema.dependencies.values.
          select { |s| s.is_a?(Schema) }.
          each { |s| yielder << s }

        # schemas contained inside hyper-schema links objects
        schema.links.map { |l| [l.schema, l.target_schema] }.
          flatten.
          compact.
          each { |s| yielder << s }
      end
    end

    def unresolved_refs(schema)
      # prevent endless recursion
      return [] unless schema.original?

      schema_children(schema).reduce([]) do |arr, subschema|
        if !subschema.expanded?
          arr += [subschema.reference]
        else
          arr += unresolved_refs(subschema)
        end
      end
    end

    def traverse_schema(schema)
      @store.add_uri_reference(schema.uri, schema)

      schema_children(schema).each do |subschema|
        if subschema.reference && !subschema.expanded?
          dereference(subschema, [])
        end

        # traverse child schemas only if they're the original copy
        if subschema.expanded? && subschema.original?
          traverse_schema(subschema)
        end
      end

      # after finishing a schema traversal, find all clones and re-hydrate them
      if schema.original?
        schema.clones.each do |clone_schema|
          parent = clone_schema.parent
          clone_schema.copy_from(schema)
          clone_schema.parent = parent
        end
      end
    end
  end
end
