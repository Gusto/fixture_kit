# frozen_string_literal: true

require "open3"

RSpec.describe "Dummy app integration" do
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)
  DUMMY_RSPEC_PATH = "spec/integration/fixture_kit_integration.rb"
  DUMMY_MINITEST_PATH = "test/integration/fixture_kit_integration_test.rb"
  INTEGRATION_FRAMEWORK = ENV.fetch("FIXTURE_KIT_INTEGRATION_FRAMEWORK", "rspec")

  def run_dummy_tests
    command =
      case INTEGRATION_FRAMEWORK
      when "rspec"
        [
          "bundle",
          "exec",
          "bin/rspec",
          "--no-color",
          "--format",
          "documentation",
          DUMMY_RSPEC_PATH
        ]
      when "minitest"
        [
          "bundle",
          "exec",
          "bin/rails",
          "test",
          DUMMY_MINITEST_PATH,
          "-v"
        ]
      else
        raise ArgumentError, "Unsupported integration framework: #{INTEGRATION_FRAMEWORK}"
      end

    Open3.capture3(
      {
        "RAILS_ENV" => "test",
        "FIXTURE_KIT_INTEGRATION_FRAMEWORK" => INTEGRATION_FRAMEWORK
      },
      *command,
      chdir: DUMMY_ROOT
    )
  end

  it "runs fixture_kit behavior in a standalone dummy app" do
    stdout, stderr, status = run_dummy_tests
    output = [stdout, stderr].join("\n")

    expect(status.success?).to be(true), <<~MESSAGE
      Expected dummy app integration run to pass.
      Command output:
      #{output}
    MESSAGE

    expected_markers = [
      "FKIT_ASSERT:FRAMEWORK:#{INTEGRATION_FRAMEWORK}",
      "FKIT_ASSERT:PRELOAD_BEFORE_HOOK",
      "FKIT_ASSERT:MULTI_DB_COUNTS",
      "FKIT_ASSERT:EXPOSED_ACCESS",
      "FKIT_ASSERT:ARRAY_EXPOSURE",
      "FKIT_ASSERT:CACHE_WRITTEN",
      "FKIT_ASSERT:NESTED_FIXTURE",
      "FKIT_ASSERT:QUERY_TYPES_CAPTURED",
      "FKIT_ASSERT:ROLLBACK_FIRST_EXAMPLE",
      "FKIT_ASSERT:ROLLBACK_SECOND_EXAMPLE",
      "FKIT_ASSERT:ANONYMOUS_FIXTURE",
      "FKIT_ASSERT:ANONYMOUS_CACHE_PATH",
      "FKIT_ASSERT:ANONYMOUS_HELPER_METHODS",
      "FKIT_ASSERT:INHERITANCE_CHAIN",
      "FKIT_ASSERT:INLINE_INHERITANCE",
      "FKIT_ASSERT:CIRCULAR_INHERITANCE",
      "FKIT_ASSERT:ANONYMOUS_NESTED_OVERRIDE",
      "FKIT_ASSERT:ANONYMOUS_DUPLICATE_DECLARATION",
      "FKIT_ASSERT:UNDECLARED_FIXTURE_READER",
      "FKIT_ASSERT:UNSCOPED_RECORD_LOOKUP"
    ]

    if INTEGRATION_FRAMEWORK == "rspec"
      expected_markers += [
        "FKIT_ASSERT:SHARED_EXAMPLE_FIXTURE_ACCESS",
        "FKIT_ASSERT:SHARED_EXAMPLE_HOST_FIXTURE"
      ]
    end

    expected_markers.each do |marker|
      expect(output).to include(marker), "Expected marker #{marker.inspect} in output.\nOutput:\n#{output}"
    end

  end
end
