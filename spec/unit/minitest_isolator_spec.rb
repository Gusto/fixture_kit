# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Minitest::Isolator do
  describe ".run" do
    it "builds an ActiveSupport::TestCase harness" do
      captured_test_case_class = nil

      allow(Minitest::Runnable.runnables).to receive(:delete).and_wrap_original do |original, test_case_class|
        captured_test_case_class = test_case_class
        original.call(test_case_class)
      end

      described_class.run { nil }

      expect(captured_test_case_class).to be < ActiveSupport::TestCase
      expect(captured_test_case_class.included_modules).to include(ActiveRecord::TestFixtures)
      expect(captured_test_case_class.public_instance_methods(false).map(&:to_s))
        .to include(described_class::TEST_METHOD_NAME)
    end

    it "does not leak harness test cases into minitest runnables" do
      runnables_before = Minitest::Runnable.runnables.dup

      described_class.run { nil }

      expect(Minitest::Runnable.runnables).to eq(runnables_before)
    end

    it "re-raises errors from the harness block" do
      runnables_before = Minitest::Runnable.runnables.dup

      expect do
        described_class.run do
          raise "harness exploded"
        end
      end.to raise_error(RuntimeError, "harness exploded")

      expect(Minitest::Runnable.runnables).to eq(runnables_before)
    end

    it "raises FixtureKit::PregenerationError when run fails without a failure" do
      isolator = described_class.new
      result = instance_double(Minitest::Result, passed?: false, failures: [])
      test_case = instance_double(ActiveSupport::TestCase, run: result)

      allow(described_class).to receive(:new).and_return(isolator)
      allow(isolator).to receive(:build_test_class).and_return(test_case)

      expect { described_class.run { nil } }
        .to raise_error(FixtureKit::PregenerationError, "FixtureKit pregeneration failed")
    end
  end
end
