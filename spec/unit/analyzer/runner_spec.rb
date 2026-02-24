# frozen_string_literal: true

require "json"
require "tempfile"
require "fixture_kit/analyzer"
require_relative "../../support/analyzer_helpers"

RSpec.describe FixtureKit::Analyzer::Runner do
  include AnalyzerHelpers

  let(:sample_spec) { File.expand_path("../../fixtures/analyzer/sample_spec.rb", __dir__) }
  let(:expected_output) { JSON.parse(File.read(File.expand_path("../../fixtures/analyzer/expected_output.json", __dir__))) }

  # Build the same tree structure as sample_spec.rb describes
  let(:example_groups) do
    child_with_admin = AnalyzerHelpers::FakeGroup.new(
      description: "with admin",
      file_path: sample_spec,
      examples: 2,
      lets: {admin: {file: sample_spec, line: 16}},
      children: [
        AnalyzerHelpers::FakeGroup.new(description: "deeply nested", file_path: sample_spec, examples: 1),
      ],
    )
    child_with_override = AnalyzerHelpers::FakeGroup.new(
      description: "with override",
      file_path: sample_spec,
      examples: 2,
      lets: {company: {file: sample_spec, line: 27}},
    )
    [
      AnalyzerHelpers::FakeGroup.new(
        description: "Orders",
        file_path: sample_spec,
        examples: 3,
        lets: {
          company: {file: sample_spec, line: 7},
          employee: {file: sample_spec, line: 8},
          plain_value: {file: sample_spec, line: 9},
        },
        children: [child_with_admin, child_with_override],
      ),
    ]
  end

  describe "#run" do
    it "produces the expected JSON output" do
      runner = described_class.new(format: "json", min_reuse: 1)
      results = runner.run(example_groups)
      actual = results.map(&:to_h)

      # Normalize file paths to relative for comparison
      normalize = ->(data) do
        data.map do |file_result|
          file_result.transform_keys(&:to_s).tap do |h|
            h["file"] = File.basename(h["file"])
            h["lets"] = h["lets"].map do |l|
              l.transform_keys(&:to_s).tap do |lh|
                lh["defined_at"] = lh["defined_at"].sub(%r{.*/}, "")
              end
            end
          end
        end
      end

      expect(normalize.call(actual)).to eq(normalize.call(expected_output))
    end

    it "writes JSON to output_path when specified" do
      Tempfile.create(["analyzer", ".json"]) do |f|
        runner = described_class.new(format: "text", output_path: f.path, min_reuse: 1)
        runner.run(example_groups)

        written = JSON.parse(File.read(f.path))
        expect(written.length).to eq(1)
        expect(written.first["total_examples"]).to eq(8)
      end
    end

    it "returns empty array for empty input" do
      runner = described_class.new
      expect(runner.run([])).to be_nil
    end

    it "respects min_reuse filtering in text output" do
      output = StringIO.new
      # Capture stdout to verify text output filters correctly
      runner = described_class.new(format: "text", min_reuse: 10)

      $stdout = output
      runner.run(example_groups)
      $stdout = STDOUT

      expect(output.string).to include("0 with max reuse >= 10")
    end
  end
end
