# frozen_string_literal: true

require "open3"

RSpec.describe "Dummy app STI integration" do
  STI_DUMMY_ROOT = File.expand_path("../dummy", __dir__)
  STI_RSPEC_PATH = "spec/integration/sti_integration.rb"
  STI_MINITEST_PATH = "test/integration/sti_integration_test.rb"
  STI_INTEGRATION_FRAMEWORK = ENV.fetch("FIXTURE_KIT_INTEGRATION_FRAMEWORK", "rspec")

  def run_dummy_tests
    command =
      case STI_INTEGRATION_FRAMEWORK
      when "rspec"
        [
          "bundle",
          "exec",
          "bin/rspec",
          "--no-color",
          "--format",
          "documentation",
          STI_RSPEC_PATH
        ]
      when "minitest"
        [
          "bundle",
          "exec",
          "bin/rails",
          "test",
          STI_MINITEST_PATH,
          "-v"
        ]
      else
        raise ArgumentError, "Unsupported integration framework: #{STI_INTEGRATION_FRAMEWORK}"
      end

    Open3.capture3(
      {
        "RAILS_ENV" => "test",
        "FIXTURE_KIT_INTEGRATION_FRAMEWORK" => STI_INTEGRATION_FRAMEWORK
      },
      *command,
      chdir: STI_DUMMY_ROOT
    )
  end

  it "restores STI subclass records that share a table" do
    stdout, stderr, status = run_dummy_tests
    output = [stdout, stderr].join("\n")

    expect(status.success?).to be(true), <<~MESSAGE
      Expected dummy app STI integration run to pass.
      Command output:
      #{output}
    MESSAGE

    expected_markers = [
      "FKIT_ASSERT:STI_RECORDS_RESTORED",
      "FKIT_ASSERT:STI_ROLLBACK_CLEAN"
    ]

    expected_markers.each do |marker|
      expect(output).to include(marker), "Expected marker #{marker.inspect} in output.\nOutput:\n#{output}"
    end
  end
end
