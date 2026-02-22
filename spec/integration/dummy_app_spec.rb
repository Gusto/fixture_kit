# frozen_string_literal: true

require "open3"

RSpec.describe "Dummy app integration" do
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)
  DUMMY_SPEC_PATH = "spec/integration/fixture_kit_integration.rb"
  INTEGRATION_FRAMEWORK = ENV.fetch("FIXTURE_KIT_INTEGRATION_FRAMEWORK", "rspec")

  def run_dummy_specs
    Open3.capture3(
      {
        "RAILS_ENV" => "test",
        "FIXTURE_KIT_INTEGRATION_FRAMEWORK" => INTEGRATION_FRAMEWORK
      },
      "bundle",
      "exec",
      "bin/rspec",
      "--no-color",
      "--format",
      "documentation",
      DUMMY_SPEC_PATH,
      chdir: DUMMY_ROOT
    )
  end

  it "runs fixture_kit behavior in a standalone dummy app" do
    stdout, stderr, status = run_dummy_specs
    output = [stdout, stderr].join("\n")

    expect(status.success?).to be(true), <<~MESSAGE
      Expected dummy app RSpec run to pass.
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
      "FKIT_ASSERT:ROLLBACK_FIRST_EXAMPLE",
      "FKIT_ASSERT:ROLLBACK_SECOND_EXAMPLE"
    ]

    expected_markers.each do |marker|
      expect(output).to include(marker), "Expected marker #{marker.inspect} in output.\nOutput:\n#{output}"
    end
  end
end
