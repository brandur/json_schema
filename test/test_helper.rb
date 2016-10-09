if RUBY_VERSION >= '2.0.0'
  require 'simplecov'
  SimpleCov.start do
    add_filter "/test/"
  end
end

require "minitest"
require "minitest/autorun"
#require "pry-rescue/minitest"
require_relative "data_scaffold"
