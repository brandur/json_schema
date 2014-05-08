require_relative "jsonpointer/evaluator"

module Jsonpointer
  def self.evaluate(data, path)
    Evaluator.new(data).evaluate(path)
  end

  def self.evaluate_json(json, path)
    data = MultiJson.decode(json)
    Evaluator.new(data).evaluate(path)
  end
end
