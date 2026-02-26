# frozen_string_literal: true

require "open3"
require "json"
require "tempfile"

RSpec.describe "Analyzer integration" do
  FIXTURE_KIT_ROOT = File.expand_path("../..", __dir__)
  SAMPLE_SPEC = File.expand_path("../fixtures/analyzer/sample_spec.rb", __dir__)
  EXPECTED_OUTPUT = File.expand_path("../fixtures/analyzer/expected_output.json", __dir__)

  it "produces expected JSON output when run with rspec --dry-run" do
    Tempfile.create(["analyzer_output", ".json"]) do |output_file|
      stdout, stderr, status = Open3.capture3(
        {
          "ANALYZER_FORMAT" => "json",
          "ANALYZER_MIN_REUSE" => "1",
          "ANALYZER_OUTPUT" => output_file.path,
        },
        "bundle", "exec", "rspec",
        "--dry-run",
        "--require", "./lib/fixture_kit/analyzer",
        "--no-color",
        SAMPLE_SPEC,
        chdir: FIXTURE_KIT_ROOT,
      )

      output = [stdout, stderr].join("\n")
      expect(status.success?).to be(true), <<~MSG
        Expected rspec --dry-run to succeed.
        Output:
        #{output}
      MSG

      actual = JSON.parse(File.read(output_file.path))
      expected = JSON.parse(File.read(EXPECTED_OUTPUT))

      # Normalize absolute paths to basenames for comparison
      normalize = lambda do |data|
        data.map do |file_result|
          file_result.merge(
            "file" => File.basename(file_result["file"]),
            "lets" => file_result["lets"].map do |l|
              l.merge("defined_at" => l["defined_at"].sub(%r{.*/}, ""))
            end,
          )
        end
      end

      expect(normalize.call(actual)).to eq(normalize.call(expected))
    end
  end
end
