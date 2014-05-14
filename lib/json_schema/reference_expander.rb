require "set"

module JsonSchema
  class ReferenceExpander
    attr_accessor :errors

    def expand(schema)
      @errors = []
      @schema = schema
      @unresolved_refs = Set.new
      last_num_unresolved_refs = 0

      # The URI map helps resolve URI-based JSON pointers by storing IDs that
      # we've seen in the schema.
      #
      # Each URI tuple also contains a pointer map that helps speed up
      # expansions that have already happened and handles cyclic dependencies.
      # Store a reference to the top-level schema before doing anything else.
      @uri_map = {}
      add_uri_reference("/", schema)

      loop do
        traverse_schema(schema)

        # nothing left unresolved, we're done!
        if @unresolved_refs.count == 0
          break
        end

        # a new traversal pass still hasn't managed to resolve anymore
        # references; we're out of luck
        if @unresolved_refs.count == last_num_unresolved_refs
          refs = @unresolved_refs.to_a.join(", ")
          message = %{Couldn't resolve references (possible circular dependency): #{refs}.}
          @errors << SchemaError.new(schema, message)
          break
        end

        last_num_unresolved_refs = @unresolved_refs.count
      end

      @errors.count == 0
    end

    def expand!(schema)
      if !expand(schema)
        raise SchemaError.aggregate(@errors)
      end
      true
    end

    private

    def add_uri_reference(uri, schema)
      raise "can't add nil URI" if uri.nil?

      # Children without an ID keep the same URI as their parents. So since we
      # traverse trees from top to bottom, just keep the first reference.
      if !@uri_map.key?(uri)
        @uri_map[uri] = {
          pointer_map: {
            JsonReference.reference("#").to_s => schema
          },
          schema: schema
        }
      end
    end

    def add_pointer_reference(uri, path, schema)
      @uri_map[uri][:pointer_map][path] = schema
    end

    def dereference(ref_schema)
      ref = ref_schema.reference
      uri = ref.uri

      if uri && uri.host
        scheme = uri.scheme || "http"
        message = %{Reference resolution over #{scheme} is not currently supported.}
        @errors << SchemaError.new(ref_schema, message)
      # absolute
      elsif uri && uri.path[0] == "/"
        resolve(ref_schema, uri.path)
      # relative
      elsif uri
        # build an absolute path using the URI of the current schema
        schema_uri = ref_schema.uri.chomp("/")
        resolve(ref_schema, schema_uri + "/" + uri.path)
      # just a JSON Pointer -- resolve against schema root
      else
        evaluate(ref_schema, "/", @schema)
      end
    end

    def evaluate(ref_schema, uri_path, resolved_schema)
      ref = ref_schema.reference

      # we've already evaluated this precise URI/pointer combination before
      if !(new_schema = lookup_pointer(uri_path, ref.pointer.to_s))
        data = JsonPointer.evaluate(resolved_schema.data, ref.pointer)

        # couldn't resolve pointer within known schema; that's an error
        if data.nil?
          message = %{Couldn't resolve pointer "#{ref.pointer}".}
          @errors << SchemaError.new(resolved_schema, message)
          return nil
        end

        # this counts as a resolution
        @unresolved_refs.delete(ref.to_s)

        # parse a new schema and use the same parent node
        new_schema = Parser.new.parse(data, ref_schema.parent)

        # TODO: recursion ...
        add_pointer_reference(uri_path, ref.pointer.to_s, new_schema)

        # mark a new unresolved reference if the schema we got back is also a
        # reference
        if new_schema.reference
          @unresolved_refs.add(new_schema.reference.to_s)
        end
      end

      # copy new schema into existing one while preserving parent
      parent = ref_schema.parent
      ref_schema.copy_from(new_schema)
      ref_schema.parent = parent

      nil
    end

    def lookup_pointer(uri, pointer)
      @uri_map[uri][:pointer_map][pointer]
    end

    def lookup_uri(uri)
      if @uri_map[uri]
        @uri_map[uri][:schema]
      else
        nil
      end
    end

    def resolve(ref_schema, uri_path)
      if schema = lookup_uri(uri_path)
        evaluate(ref_schema, uri_path, schema)
      else
        # couldn't resolve, return original reference
        @unresolved_refs.add(ref_schema.reference.to_s)
        ref_schema
      end
    end

    def schema_children(schema)
      Enumerator.new do |yielder|
        schema.all_of.each { |s| yielder << s }
        schema.any_of.each { |s| yielder << s }
        schema.one_of.each { |s| yielder << s }
        schema.definitions.each { |_, s| yielder << s }
        schema.links.map { |l| l.schema }.compact.each { |s| yielder << s }
        schema.pattern_properties.each { |_, s| yielder << s }
        schema.properties.each { |_, s| yielder << s }

        if schema.not
          yielder << schema.not
        end

        # can either be a single schema (list validation) or multiple (tuple
        # validation)
        if schema.items
          if schema.items.is_a?(Array)
            schema.items.each { |s| yielder << s }
          else
            yielder << schema.items
          end
        end

        # dependencies can either be simple or "schema"; only replace the
        # latter
        schema.dependencies.values.
          select { |s| s.is_a?(Schema) }.
          each { |s| yielder << s }
      end
    end

    def traverse_schema(schema)
      if !schema.reference
        add_uri_reference(schema.uri, schema)
      end

      schema_children(schema).each do |subschema|
        if subschema.reference
          dereference(subschema)
        end
        traverse_schema(subschema)
      end
    end
  end
end
