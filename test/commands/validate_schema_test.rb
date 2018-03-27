require "test_helper"

require "commands/validate_schema"
require "tempfile"

describe Commands::ValidateSchema do
  before do
    @command = Commands::ValidateSchema.new
  end

  it "shows usage with no arguments" do
    success = @command.run([])
    assert_equal [], @command.errors
    assert_equal [], @command.messages
    refute success
  end

  it "runs successfully in fail fast mode" do
    temp_file(basic_schema) do |path|
      @command.fail_fast = true
      success = @command.run([schema_path, path])
      assert_equal [], @command.errors
      assert_equal ["#{path} is valid."], @command.messages
      assert success
    end
  end

  it "runs successfully in detect mode" do
    temp_file(basic_schema) do |path|
      @command.extra_schemas << schema_path
      @command.detect = true
      success = @command.run([path])
      assert_equal [], @command.errors
      assert_equal ["#{path} is valid."], @command.messages
      assert success
    end
  end

  it "runs successfully out of detect mode" do
    temp_file(basic_schema) do |path|
      @command.detect = false
      success = @command.run([schema_path, path])
      assert_equal [], @command.errors
      assert_equal ["#{path} is valid."], @command.messages
      assert success
    end
  end

  it "takes extra schemas" do
    temp_file(basic_hyper_schema) do |path|
      @command.detect = false
      @command.extra_schemas << schema_path
      success = @command.run([hyper_schema_path, path])
      assert_equal [], @command.errors
      assert_equal ["#{path} is valid."], @command.messages
      assert success
    end
  end

  it "requires at least one argument in detect mode" do
    @command.detect = true
    success = @command.run([])
    assert_equal [], @command.errors
    assert_equal [], @command.messages
    refute success
  end

  it "requires at least two arguments out of detect mode" do
    @command.detect = false
    success = @command.run([hyper_schema_path])
    assert_equal [], @command.errors
    assert_equal [], @command.messages
    refute success
  end

  it "errors on invalid files" do
    @command.detect = false
    success = @command.run(["dne-1", "dne-2"])
    assert_equal ["dne-1: No such file or directory."], @command.errors
    assert_equal [], @command.messages
    refute success
  end

  it "errors on empty files" do
    temp_file("") do |path|
      success = @command.run([hyper_schema_path, path])
      assert_equal ["#{path}: File is empty."], @command.errors
      refute success
    end
  end

  def basic_hyper_schema
    <<-eos
      { "$schema": "http://json-schema.org/draft-04/hyper-schema" }
    eos
  end

  def basic_schema
    <<-eos
      { "$schema": "http://json-schema.org/draft-04/schema" }
    eos
  end

  def hyper_schema_path
    File.expand_path("schema.json", "#{__FILE__}/../../../schemas")
  end

  def schema_path
    File.expand_path("schema.json", "#{__FILE__}/../../../schemas")
  end

  def temp_file(contents)
    file = Tempfile.new("schema")
    file.write(contents)
    file.size() # flush
    yield(file.path)
  ensure
    file.close
    file.unlink
  end
end
