require "json_schema/parser"
require "set"

module JsonSchema
  class ReferenceExpander
    def initialize(schema)
      @schema = schema
    end

    def expand
      @errors = []
      @store = {}
      @unresolved_refs = Set.new
      last_num_unresolved_refs = 0

      loop do
        traverse_schema(@schema)

        # nothing left unresolved, we're done!
        if @unresolved_refs.count == 0
          break
        end

        # a new traversal pass still hasn't managed to resolved anymore
        # references; we're out of luck
        if @unresolved_refs.count == last_num_unresolved_refs
          refs = @unresolved_refs.to_a.join(", ")
          @errors << SchemaError.new(
            @schema,
            %{Couldn't resolve references: #{refs}.}
          )
          break
        end

        last_num_unresolved_refs = @unresolved_refs.count
      end

      @errors.count == 0
    end

    def expand!
      if !expand
        raise SchemaError.aggregate(@errors)
      end
    end

    private

    def dereference(key, schema)
      ref = schema.reference
      uri = ref.uri

      if uri && uri.host
        scheme = uri.scheme || "http"
        @errors << SchemaError.new(
          schema,
          %{Reference resolution over #{scheme} is not currently supported.}
        )
      # absolute
      elsif uri && uri.path[0] == "/"
        resolve(key, schema, uri.path, ref)
      # relative
      elsif uri
        # build an absolute path using the URI of the current schema
        schema_uri = schema.uri.chomp("/")
        resolve(key, schema, schema_uri + "/" + uri.path, ref)
      # just a JSON Pointer -- resolve against schema root
      else
        evaluate(key, schema, @schema, ref)
      end
    end

    def evaluate(key, schema, schema_context, ref)
      data = JsonPointer.evaluate(schema_context.data, ref.pointer)

      # couldn't resolve pointer within known schema; that's an error
      if data.nil?
        @errors << SchemaError.new(
          schema_context,
          %{Couldn't resolve pointer "#{ref.pointer}".}
        )
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

      parent = schema.parent
      schema.copy_from(new_schema)
      schema.parent = parent

      new_schema
    end

    def resolve(key, schema, uri, ref)
      if schema_context = @store[uri]
        evaluate(key, schema, schema_context, ref)
      else
        # couldn't resolve, return original reference
        @unresolved_refs.add(ref.to_s)
        schema
      end
    end

    def traverse_schema(schema)
      # Children without an ID keep the same URI as their parents. So since we
      # traverse trees from top to bottom, just keep the first reference.
      if !@store.key?(schema.uri)
        @store[schema.uri] = schema
      end

      schema.children.each do |key, child_schema|
        if child_schema.reference
          dereference(key, child_schema)
        end
        traverse_schema(child_schema)
      end
    end
  end
end
