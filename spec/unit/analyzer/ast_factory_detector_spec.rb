# frozen_string_literal: true

require "fixture_kit/analyzer"

RSpec.describe FixtureKit::Analyzer::AstFactoryDetector do
  let(:detector) { described_class.new }
  let(:sample_spec) { File.expand_path("../../fixtures/analyzer/sample_spec.rb", __dir__) }

  def make_module_with_method(file, line)
    mod = Module.new
    # Define a method whose source_location points to the sample file at the given line.
    # We use eval so Ruby records the file/line we want.
    mod.module_eval(<<~RUBY, file, line)
      def target_method; end
    RUBY
    mod
  end

  describe "#detect" do
    it "detects a create(:company) factory call" do
      mod = make_module_with_method(sample_spec, 7)
      expect(detector.detect(mod, :target_method)).to eq(["company"])
    end

    it "detects a create(:employee) factory call" do
      mod = make_module_with_method(sample_spec, 8)
      expect(detector.detect(mod, :target_method)).to eq(["employee"])
    end

    it "returns empty for a let with no factory calls" do
      mod = make_module_with_method(sample_spec, 9)
      expect(detector.detect(mod, :target_method)).to eq([])
    end

    it "detects factory calls in nested contexts" do
      mod = make_module_with_method(sample_spec, 16)
      expect(detector.detect(mod, :target_method)).to eq(["admin_user"])
    end

    it "returns empty for a nonexistent file" do
      mod = Module.new
      mod.module_eval(<<~RUBY, "/nonexistent/file.rb", 1)
        def target_method; end
      RUBY
      expect(detector.detect(mod, :target_method)).to eq([])
    end
  end
end
