require "set"

module JsonSchema
  class ReferenceExpander
    attr_accessor :errors
    attr_accessor :store

    def expand(schema, options = {})
      @errors       = []
      @local_store  = DocumentStore.new
      @schema       = schema
      @schema_paths = {}
      @store        = options[:store] || DocumentStore.new
      @uri          = URI.parse(schema.uri)

      @store.each do |uri, store_schema|
        build_schema_paths(uri, store_schema)
      end

      # we run #to_s on lookup for URIs; the #to_s of nil is ""
      build_schema_paths("", schema)

      traverse_schema(schema)

      refs = unresolved_refs(schema).sort
      if refs.count > 0
        message = %{Couldn't resolve references: #{refs.to_a.join(", ")}.}
        @errors << SchemaError.new(schema, message, :unresolved_references)
      end

      @errors.count == 0
    end

    def expand!(schema, options = {})
      if !expand(schema, options)
        raise AggregateError.new(@errors)
      end
      true
    end

    private

    def add_reference(schema)
      uri = URI.parse(schema.uri)

      # In case we've already added a schema for the same reference, don't
      # re-add it unless the new schema's pointer path is shorter than the one
      # we've already stored.
      stored_schema = lookup_reference(uri)
      if stored_schema && stored_schema.pointer.length < schema.pointer.length
        return
      end

      if uri.absolute?
        @store.add_schema(schema)
      else
        @local_store.add_schema(schema)
      end
    end

    def build_schema_paths(uri, schema)
      return if schema.reference

      paths = @schema_paths[uri] ||= {}
      paths[schema.pointer] = schema

      schema_children(schema).each do |subschema|
        build_schema_paths(uri, subschema)
      end

      # Also insert alternate tree for schema's custom URI. O(crazy).
      if schema.uri != uri
        fragment, parent = schema.fragment, schema.parent
        schema.fragment, schema.parent = "#", nil
        build_schema_paths(schema.uri, schema)
        schema.fragment, schema.parent = fragment, parent
      end
    end

    def dereference(ref_schema, ref_stack)
      ref = ref_schema.reference

      # detects a reference cycle
      if ref_stack.include?(ref)
        message = %{Reference loop detected: #{ref_stack.sort.join(", ")}.}
        @errors << SchemaError.new(ref_schema, message, :loop_detected)
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

    def lookup_pointer(uri, pointer)
      paths = @schema_paths[uri.to_s] ||= {}
      paths[pointer]
    end

    def lookup_reference(uri)
      if uri.absolute?
        @store.lookup_schema(uri.to_s)
      else
        @local_store.lookup_schema(uri.to_s)
      end
    end

    def resolve_pointer(ref_schema, resolved_schema)
      ref = ref_schema.reference

      if !(new_schema = lookup_pointer(ref.uri, ref.pointer))
        data = JsonPointer.evaluate(resolved_schema.data, ref.pointer)

        # couldn't resolve pointer within known schema; that's an error
        if data.nil?
          message = %{Couldn't resolve pointer "#{ref.pointer}".}
          @errors << SchemaError.new(resolved_schema, message, :unresolved_pointer)
          return
        end

        # Try to aggressively detect a circular dependency in case of another
        # reference. See:
        #
        #     https://github.com/brandur/json_schema/issues/50
        #
        if new_schema = lookup_pointer(ref.uri, data["$ref"])
          new_schema.clones << ref_schema
        else
          # Parse a new schema and use the same parent node. Basically this is
          # exclusively for the case of a reference that needs to be
          # de-referenced again to be resolved.
          # TODO: Fix to never parse.
          new_schema = Parser.new.parse(data, ref_schema.parent)
          build_schema_paths(ref.uri, resolved_schema)
        end
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
        if @store.lookup_schema(uri.to_s)
          resolve_uri(ref_schema, uri)
        else
          message =
            %{Reference resolution over #{scheme} is not currently supported.}
          @errors << SchemaError.new(ref_schema, message, :scheme_not_supported)
          nil
        end
      # absolute
      elsif uri && uri.path[0] == "/"
        resolve_uri(ref_schema, uri)
      # relative
      elsif uri && ref_schema.uri
        # build an absolute path using the URI of the current schema
        # TODO: fix this. References don't get URIs which might be an error.
        schema_uri = ref_schema.uri.chomp("/")
        resolve_uri(ref_schema, URI.parse(schema_uri + "/" + uri.path))
      # just a JSON Pointer -- resolve against schema root
      else
        resolve_pointer(ref_schema, @schema)
      end
    end

    def resolve_uri(ref_schema, uri)
      if schema = lookup_reference(uri)
        resolve_pointer(ref_schema, schema)
      else
        message = %{Couldn't resolve URI: #{uri.to_s}.}
        @errors << SchemaError.new(ref_schema, message, :unresolved_pointer)
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
      add_reference(schema)

      schema_children(schema).each do |subschema|
        if subschema.reference && !subschema.expanded?
          dereference(subschema, [])
        end

        if !subschema.reference
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
