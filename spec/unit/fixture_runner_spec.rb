# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FixtureRunner do
  describe "#generate_cache_only" do
    it "uses the configured generator" do
      generator = class_double("CustomGenerator")
      runner = described_class.new("project_management")

      previous_generator = FixtureKit.configuration.generator
      FixtureKit.configuration.generator = generator

      expect(FixtureKit::FixtureCache).to receive(:clear).with("project_management")
      expect(generator).to receive(:run).and_yield
      expect(runner).to receive(:execute_and_cache)

      expect(runner.generate_cache_only).to be(true)
    ensure
      FixtureKit.configuration.generator = previous_generator
    end
  end
end
