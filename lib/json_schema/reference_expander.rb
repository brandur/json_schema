require "json_schema/parser"
require "set"

module JsonSchema
  class ReferenceExpander
    def initialize(schema)
      @schema = schema
    end

    def expand!
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
          raise(%{Couldn't resolve references: #{refs}.})
        end

        last_num_unresolved_refs = @unresolved_refs
      end
    end

    private

    def dereference(schema)
      ref = schema.reference
      uri = ref.uri

      if uri && uri.host
        scheme = uri.scheme || "http"
        raise "Reference resolution over #{scheme} is not currently supported."
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
        raise %{Couldn't resolve pointer "#{ref.pointer}" in schema "#{schema_context.uri}".}
      end

      # parse a new schema and use the same parent node
      new_schema = Parser.new.parse(data, schema.parent)

      # remove old schema from parent's children, and re-link the new one
      if schema.parent
        schema.parent.replace_reference(ref, new_schema)
      end

      new_schema
    end

    def resolve(schema, uri, ref)
      if schema_context = @store[uri]
        @unresolved_refs.delete(ref.to_s)
        evaluate(schema, schema_context, ref)
      else
        @unresolved_refs.add(ref.to_s)

        # couldn't resolve, return original reference
        schema
      end
    end

    def traverse_schema(schema)
      # Children without an ID keep the same URI as their parents. So since we
      # traverse trees from top to bottom, just keep the first reference.
      if !@store.key?(schema.uri)
        @store[schema.uri] = schema
      end

      schema.children.each do |child_schema|
        if child_schema.reference
          dereference(child_schema)
        end
        traverse_schema(child_schema)
      end
    end
  end
end
