module JsonSchema
  # The document store helps resolve URI-based JSON pointers by storing IDs
  # that we've seen in the schema.
  #
  # Each URI tuple also contains a pointer map that helps speed up expansions
  # that have already happened and handles cyclic dependencies. Store a
  # reference to the top-level schema before doing anything else.
  class DocumentStore
    def initialize
      @schema_map = {}
    end

    def add_uri_reference(uri, schema)
      raise "can't add nil URI" if uri.nil?
      @schema_map[uri] = schema
    end

    def each
      @schema_map.each { |k, v| yield(k, v) }
    end

    def lookup_uri(uri)
      @schema_map[uri]
    end
  end
end
