module JsonPointer
  # Evaluates a JSON pointer within a JSON document.
  #
  # Note that this class is designed to evaluate references across a plain JSON
  # data object _or_ an instance of `JsonSchema::Schema`, so the constructor's
  # `data` argument can be of either type.
  class Evaluator
    def initialize(data)
      @data = data
    end

    def evaluate(original_path)
      path = original_path

      # the leading # can either be included or not
      path = path[1..-1] if path[0] == "#"

      # special case on "" or presumably "#"
      if path.empty?
        return @data
      end

      if path[0] != "/"
        raise ArgumentError, %{Path must begin with a leading "/": #{original_path}.}
      end

      path_parts = split(path)
      evaluate_segment(@data, path_parts)
    end

    private

    def evaluate_segment(data, path_parts)
      if path_parts.empty?
        data
      elsif data == nil
        # spec doesn't define how to handle this, so we'll return `nil`
        nil
      else
        key = transform_key(path_parts.shift)
        if data.is_a?(Array)
          unless key =~ /^\d+$/
            raise ArgumentError, %{Key operating on an array must be a digit or "-": #{key}.}
          end
          evaluate_segment(data[key.to_i], path_parts)
        else
          evaluate_segment(data[key], path_parts)
        end
      end
    end

    # custom split method to account for blank segments
    def split(path)
      parts = []
      last_index = 0
      while index = path.index("/", last_index)
        if index == last_index
          parts << ""
        else
          parts << path[last_index...index]
        end
        last_index = index + 1
      end
      # and also get that last segment
      parts << path[last_index..-1]
      # it should begin with a blank segment from the leading "/"; kill that
      parts.shift
      parts
    end

    def transform_key(key)
      # ~ has special meaning to JSON pointer to allow keys containing "/", so
      # perform some transformations first as defined by the spec
      # first as defined by the spec
      key = key.gsub('~1', '/')
      key = key.gsub('~0', '~')
      key
    end
  end
end
