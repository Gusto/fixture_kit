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
      expect(captured_test_case_class.public_instance_methods(false).map(&:to_s))
        .to include("test_fixture_kit_cache_pregeneration")
    end

    it "builds a fresh harness class for each execute on the same adapter instance" do
      captured_test_case_classes = []

      allow(Minitest::Runnable.runnables).to receive(:delete).and_wrap_original do |original, test_case_class|
        captured_test_case_classes << test_case_class
        original.call(test_case_class)
      end

      adapter = described_class.new
      adapter.execute { nil }
      adapter.execute { nil }

      expect(captured_test_case_classes.size).to be >= 2
      expect(captured_test_case_classes[-2]).not_to equal(captured_test_case_classes[-1])
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
    it "underscores the scope class name under the anonymous directory" do
      scope = Class.new
      allow(scope).to receive(:to_s).and_return("MyFeatureTest")

      identifier = described_class.new.identifier_for(scope)

      expect(identifier).to eq("_anonymous/my_feature_test")
    end
  end
end
