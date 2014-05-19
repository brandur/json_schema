module JsonSchema
  # The document store helps resolve URI-based JSON pointers by storing IDs
  # that we've seen in the schema.
  #
  # Each URI tuple also contains a pointer map that helps speed up expansions
  # that have already happened and handles cyclic dependencies. Store a
  # reference to the top-level schema before doing anything else.
  class DocumentStore
    def initialize
      @uri_map = {}
    end

    def add_pointer_reference(uri, path, schema)
      raise "can't add nil URI" if uri.nil?

      if !@uri_map[uri][:pointer_map].key?(path)
        @uri_map[uri][:pointer_map][path] = schema
      end
    end

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
  end
end
