# frozen_string_literal: true

require "open3"

RSpec.describe "Dummy app fixture count integration" do
  COUNT_DUMMY_ROOT = File.expand_path("../dummy", __dir__)
  COUNT_DUMMY_RSPEC_PATH = "spec/integration/fixture_count_integration.rb"
  COUNT_DUMMY_MINITEST_PATH = "test/integration/fixture_count_integration_test.rb"
  COUNT_INTEGRATION_FRAMEWORK = ENV.fetch("FIXTURE_KIT_INTEGRATION_FRAMEWORK", "rspec")

  def run_dummy_tests
    command =
      case COUNT_INTEGRATION_FRAMEWORK
      when "rspec"
        [
          "bundle",
          "exec",
          "bin/rspec",
          "--no-color",
          "--format",
          "documentation",
          COUNT_DUMMY_RSPEC_PATH
        ]
      when "minitest"
        [
          "bundle",
          "exec",
          "bin/rails",
          "test",
          COUNT_DUMMY_MINITEST_PATH,
          "-v"
        ]
      else
        raise ArgumentError, "Unsupported integration framework: #{COUNT_INTEGRATION_FRAMEWORK}"
      end

    Open3.capture3(
      {
        "RAILS_ENV" => "test",
        "FIXTURE_KIT_INTEGRATION_FRAMEWORK" => COUNT_INTEGRATION_FRAMEWORK
      },
      *command,
      chdir: COUNT_DUMMY_ROOT
    )
  end

  it "does not inflate suite counts when running with fixtures" do
    stdout, stderr, status = run_dummy_tests
    output = [stdout, stderr].join("\n")

    expect(status.success?).to be(true), <<~MESSAGE
      Expected dummy app fixture count run to pass.
      Command output:
      #{output}
    MESSAGE

    expect(output).to include("FKIT_ASSERT:SINGLE_COUNT_TEST")

    case COUNT_INTEGRATION_FRAMEWORK
    when "rspec"
      expect(output).to match(/\b1 example, 0 failures\b/)
    when "minitest"
      expect(output).to match(/\b1 runs, \d+ assertions, 0 failures, 0 errors, \d+ skips\b/)
    else
      raise ArgumentError, "Unsupported integration framework: #{COUNT_INTEGRATION_FRAMEWORK}"
    end
  end
end
