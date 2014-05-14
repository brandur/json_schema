require "set"

module JsonSchema
  class ReferenceExpander
    attr_accessor :errors

    def expand(schema)
      @errors = []
      @schema = schema
      @store = {}
      @unresolved_refs = Set.new
      last_num_unresolved_refs = 0

      loop do
        traverse_schema(schema)

        # nothing left unresolved, we're done!
        if @unresolved_refs.count == 0
          break
        end

        # a new traversal pass still hasn't managed to resolved anymore
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

    def dereference(schema)
      ref = schema.reference
      uri = ref.uri

      if uri && uri.host
        scheme = uri.scheme || "http"
        message = %{Reference resolution over #{scheme} is not currently supported.}
        @errors << SchemaError.new(schema, message)
      # absolute
      elsif uri && uri.path[0] == "/"
        resolve(schema, uri.path, ref)
      # relative
      elsif uri
        # build an absolute path using the URI of the current schema
        schema_uri = schema.uri.chomp("/")
        resolve(schema, schema_uri + "/" + uri.path, ref)
      # just a JSON Pointer -- resolve against schema root
      else
        evaluate(schema, @schema, ref)
      end
    end

    def evaluate(schema, schema_context, ref)
      data = JsonPointer.evaluate(schema_context.data, ref.pointer)

      # couldn't resolve pointer within known schema; that's an error
      if data.nil?
        message = %{Couldn't resolve pointer "#{ref.pointer}".}
        @errors << SchemaError.new(schema_context, message)
        return
      end

      # this counts as a resolution
      @unresolved_refs.delete(ref.to_s)

      # parse a new schema and use the same parent node
      new_schema = Parser.new.parse(data, schema.parent)

      # mark a new unresolved reference if the schema we got back is also a
      # reference
      if new_schema.reference
        @unresolved_refs.add(new_schema.reference.to_s)
      end

      # copy new schema into existing one while preserving parent
      parent = schema.parent
      schema.copy_from(new_schema)
      schema.parent = parent

      new_schema
    end

    def resolve(schema, uri, ref)
      if schema_context = @store[uri]
        evaluate(schema, schema_context, ref)
      else
        # couldn't resolve, return original reference
        @unresolved_refs.add(ref.to_s)
        schema
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
      # Children without an ID keep the same URI as their parents. So since we
      # traverse trees from top to bottom, just keep the first reference.
      if !@store.key?(schema.uri)
        @store[schema.uri] = schema
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
