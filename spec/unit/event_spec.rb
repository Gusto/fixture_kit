# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Event do
  let(:cache_identifier) { "project_management" }
  let(:cache) { instance_double(FixtureKit::Cache, identifier: cache_identifier) }
  let(:definition) { FixtureKit.define {} }
  let(:fixture) do
    instance_double(FixtureKit::Fixture, cache: cache, definition: definition)
  end

  describe "#identifier" do
    it "delegates to the fixture cache identifier" do
      event = described_class.new(fixture)

      expect(event.identifier).to eq("project_management")
    end
  end

  describe "#path" do
    it "returns the source location of the definition block" do
      event = described_class.new(fixture)

      expect(event.path).to eq(__FILE__)
    end
  end
end
