# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FixtureRunner do
  describe "#run" do
    it "does not use the configured generator when force is true" do
      generator = class_double("CustomGenerator")
      runner = described_class.new("project_management")

      previous_generator = FixtureKit.configuration.generator
      FixtureKit.configuration.generator = generator

      expect(generator).not_to receive(:run)
      expect(runner).to receive(:execute_and_cache)

      runner.run(force: true)
    ensure
      FixtureKit.configuration.generator = previous_generator
    end

    it "bypasses cache reads when force is true" do
      runner = described_class.new("project_management")

      allow(runner.instance_variable_get(:@cache)).to receive(:exists?).and_return(true)
      expect(runner).not_to receive(:execute_from_cache)
      expect(runner).to receive(:execute_and_cache)

      runner.run(force: true)
    end
  end
end
