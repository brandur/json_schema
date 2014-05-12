require_relative "json_pointer/evaluator"

module JsonPointer
  def self.evaluate(data, path)
    Evaluator.new(data).evaluate(path)
  end
end
