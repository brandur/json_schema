require 'bundler'
require "rake/testtask"

task :default => :test

Bundler::GemHelper.install_tasks

Rake::TestTask.new do |task|
  task.libs << "lib"
  task.libs << "test"
  task.name = :test
  task.test_files = FileList["test/**/*_test.rb"]
  task.ruby_opts = '' if task.ruby_opts.nil?
  task.ruby_opts << ' -w' unless ENV['NO_WARN'] == 'true'
end
