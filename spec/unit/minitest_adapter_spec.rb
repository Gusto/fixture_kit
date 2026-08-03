# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::MinitestAdapter do
  describe "#execute" do
    it "builds an ActiveSupport::TestCase harness" do
      captured_test_case_class = nil

      allow(Minitest::Runnable.runnables).to receive(:delete).and_wrap_original do |original, test_case_class|
        captured_test_case_class = test_case_class
        original.call(test_case_class)
      end

      described_class.new.execute { nil }

      expect(captured_test_case_class).to be < ActiveSupport::TestCase
      expect(captured_test_case_class.included_modules).to include(ActiveRecord::TestFixtures)
    end

    it "defines the pregeneration test method on the instance, not the harness class" do
      harness_class = nil
      defined_on_instance = nil

      described_class.new.execute do |context|
        harness_class = context.class
        defined_on_instance = context.singleton_class
          .instance_methods(false)
          .include?(described_class::TEST_METHOD)
      end

      expect(defined_on_instance).to be(true)
      expect(harness_class.method_defined?(described_class::TEST_METHOD)).to be(false)
    end

    it "reuses one harness class across executes on the same adapter instance" do
      harness_classes = []
      adapter = described_class.new

      adapter.execute { |context| harness_classes << context.class }
      adapter.execute { |context| harness_classes << context.class }

      expect(harness_classes.size).to eq(2)
      expect(harness_classes.first).to equal(harness_classes.last)
    end

    it "leaves no per-generation state on the reused harness class" do
      adapter = described_class.new
      harness_class = nil
      adapter.execute { |context| harness_class = context.class }
      snapshot = lambda do
        [harness_class.instance_variables.sort, harness_class.public_instance_methods(false).sort]
      end
      baseline = snapshot.call

      adapter.execute { nil }
      expect { adapter.execute { raise "harness exploded" } }
        .to raise_error(RuntimeError, "harness exploded")

      expect(snapshot.call).to eq(baseline)
    end

    it "does not leak harness test cases into minitest runnables" do
      runnables_before = Minitest::Runnable.runnables.dup

      described_class.new.execute { nil }

      expect(Minitest::Runnable.runnables).to eq(runnables_before)
    end

    it "re-raises errors from the harness block" do
      runnables_before = Minitest::Runnable.runnables.dup

      expect do
        described_class.new.execute do
          raise "harness exploded"
        end
      end.to raise_error(RuntimeError, "harness exploded")

      expect(Minitest::Runnable.runnables).to eq(runnables_before)
    end

    it "re-raises the first failure error when execute fails" do
      failure_error = RuntimeError.new("harness exploded")
      failure = instance_double(Minitest::UnexpectedError, error: failure_error)
      result = instance_double(Minitest::Result, passed?: false, failures: [failure])
      allow_any_instance_of(ActiveSupport::TestCase).to receive(:run).and_return(result)

      expect { described_class.new.execute { nil } }
        .to raise_error(RuntimeError, "harness exploded")
    end
  end

  describe "#identifier_for" do
    it "underscores the scope class name" do
      scope = Class.new
      allow(scope).to receive(:to_s).and_return("MyFeatureTest")

      identifier = described_class.new.identifier_for(scope)

      expect(identifier).to eq("my_feature_test")
    end
  end
end
