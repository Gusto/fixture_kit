# frozen_string_literal: true

require "spec_helper"

RSpec.configure do |config|
  config.before(:example) do
    $fixture_kit_harness_hook_runs ||= 0
    $fixture_kit_harness_hook_runs += 1
  end
end

RSpec.describe FixtureKit::RSpecAdapter do
  describe "#execute" do
    it "runs inside an isolated RSpec example context" do
      harness_example = nil

      described_class.new.execute do
        harness_example = RSpec.current_example
      end

      expect(harness_example).to be_a(RSpec::Core::Example)
      expect(harness_example.description).to include("example at")
    end

    it "runs global before hooks during harness execution" do
      hook_runs_before = $fixture_kit_harness_hook_runs.to_i

      described_class.new.execute { nil }

      expect($fixture_kit_harness_hook_runs).to eq(hook_runs_before + 1)
    end

    it "does not add harness runs to suite reporter example stats" do
      reporter_count_before = RSpec.configuration.reporter.examples.size

      described_class.new.execute { nil }

      expect(RSpec.configuration.reporter.examples.size).to eq(reporter_count_before)
    end

    it "restores the outer rspec context after running" do
      outer_example = RSpec.current_example
      outer_scope = RSpec.current_scope

      described_class.new.execute do
        expect(RSpec.current_example).not_to eq(outer_example)
      end

      expect(RSpec.current_example).to eq(outer_example)
      expect(RSpec.current_scope).to eq(outer_scope)
    end

    it "re-raises errors from the harness block" do
      expect do
        described_class.new.execute do
          raise "harness exploded"
        end
      end.to raise_error(RuntimeError, "harness exploded")
    end

    it "reuses one harness example group across executes" do
      harness_groups = []
      adapter = described_class.new

      adapter.execute { |context| harness_groups << context.class }
      adapter.execute { |context| harness_groups << context.class }

      expect(harness_groups.size).to eq(2)
      expect(harness_groups.first).to equal(harness_groups.last)
    end

    it "assigns only one RSpec::ExampleGroups constant no matter how many times it runs" do
      adapter = described_class.new
      adapter.execute { nil }
      constants_after_first = RSpec::ExampleGroups.constants.grep(/\AFixtureKit/).size

      3.times { adapter.execute { nil } }

      expect(RSpec::ExampleGroups.constants.grep(/\AFixtureKit/).size)
        .to eq(constants_after_first)
    end

    it "does not retain the harness example after running" do
      harness_group = nil

      described_class.new.execute { |context| harness_group = context.class }

      expect(harness_group.examples).to be_empty
    end

    it "re-raises example.exception when execute returns false" do
      example_group = double("example_group")
      example = instance_double(RSpec::Core::Example)
      instance = Object.new
      failure = RuntimeError.new("harness exploded")

      allow(::RSpec::Core::ExampleGroup).to receive(:subclass).and_return(example_group)
      allow(example_group).to receive(:example).and_return(example)
      allow(example_group).to receive(:examples).and_return([])
      allow(example_group).to receive(:new).and_return(instance)
      allow(example).to receive(:run).with(instance, RSpec::Core::NullReporter).and_return(false)
      allow(example).to receive(:exception).and_return(failure)

      expect { described_class.new.execute { nil } }
        .to raise_error(RuntimeError, "harness exploded")
    end
  end

  describe "#identifier_for" do
    it "normalizes rspec example group scope names" do
      scope = Class.new
      allow(scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")

      identifier = described_class.new.identifier_for(scope)

      expect(identifier).to eq("foo/with_fixture_kit/hello")
    end
  end
end
