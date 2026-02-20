# frozen_string_literal: true

require "spec_helper"

RSpec.configure do |config|
  config.before(:example) do
    $fixture_kit_harness_hook_runs ||= 0
    $fixture_kit_harness_hook_runs += 1
  end
end

RSpec.describe FixtureKit::RSpec::Generator do
  describe ".run" do
    it "runs inside an isolated RSpec example context" do
      harness_example = nil

      described_class.run do
        harness_example = RSpec.current_example
      end

      expect(harness_example).to be_a(RSpec::Core::Example)
      expect(harness_example.metadata[:description]).to eq("FixtureKit cache pregeneration")
    end

    it "runs global before hooks during harness execution" do
      hook_runs_before = $fixture_kit_harness_hook_runs.to_i

      described_class.run { nil }

      expect($fixture_kit_harness_hook_runs).to eq(hook_runs_before + 1)
    end

    it "does not add harness runs to suite reporter example stats" do
      reporter_count_before = RSpec.configuration.reporter.examples.size

      described_class.run { nil }

      expect(RSpec.configuration.reporter.examples.size).to eq(reporter_count_before)
    end

    it "restores the outer rspec context after running" do
      outer_example = RSpec.current_example
      outer_scope = RSpec.current_scope

      described_class.run do
        expect(RSpec.current_example).not_to eq(outer_example)
      end

      expect(RSpec.current_example).to eq(outer_example)
      expect(RSpec.current_scope).to eq(outer_scope)
    end

    it "re-raises errors from the harness block" do
      expect do
        described_class.run do
          raise "harness exploded"
        end
      end.to raise_error(RuntimeError, "harness exploded")
    end

    it "raises FixtureKit::PregenerationError when run fails without an exception" do
      generator = described_class.new
      example_group = double("example_group")
      example = instance_double(RSpec::Core::Example)
      instance = Object.new

      allow(described_class).to receive(:new).and_return(generator)
      allow(generator).to receive(:build_example_group).and_return(example_group)
      allow(generator).to receive(:build_example).and_return(example)
      allow(example_group).to receive(:new).and_return(instance)
      allow(example_group).to receive(:remove_example).with(example)
      allow(example).to receive(:inspect_output).and_return("output")
      allow(example).to receive(:run).with(instance, RSpec::Core::NullReporter).and_return(false)
      allow(example).to receive(:exception).and_return(nil)

      expect { described_class.run { nil } }
        .to raise_error(FixtureKit::PregenerationError, "FixtureKit pregeneration failed")
    end
  end
end
