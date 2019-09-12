require "test_helper"

#
# The purpose of this sets of tests is just to test our Ruby executables
# where possible so that we can get very basic sanity checks on their syntax.
#
# We can do this without actually executing them with a "ruby -c" call.
#

describe "executables in bin/" do
  before do
    @bin_dir = File.expand_path("../../bin", __FILE__)
  end

  it "has roughly valid Ruby structure for validate-schema" do
    IO.popen(["ruby", "-c", File.join(@bin_dir, "validate-schema")]) { |io| io.read }
    assert_equal $?.exitstatus, 0, "Ruby syntax check failed; see error above"
  end
end
