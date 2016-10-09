if RUBY_VERSION >= '2.0.0'
  require 'simplecov'
  SimpleCov.start do
    # We do our utmost to test our executables by modularizing them into
    # testable pieces, but testing them to completion is nearly impossible as
    # far as I can tell, so include them in our tests but don't calculate
    # coverage.
    add_filter "/bin/"

    add_filter "/test/"
  end
end

require "minitest"
require "minitest/autorun"
#require "pry-rescue/minitest"
require_relative "data_scaffold"
