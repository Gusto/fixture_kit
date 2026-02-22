# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Registry do
  let(:configuration) do
    FixtureKit::Configuration.new.tap do |config|
      config.fixture_path = Rails.root.join("spec/fixture_kit").to_s
    end
  end

  describe "#add" do
    it "loads and returns a fixture by name" do
      registry = described_class.new(configuration)

      fixture = registry.add("project_management")

      expect(fixture).to be_a(FixtureKit::Fixture)
      expect(fixture.name).to eq("project_management")
    end

    it "returns the already-loaded fixture when added again" do
      registry = described_class.new(configuration)

      first = registry.add("project_management")
      second = registry.add("project_management")

      expect(second).to equal(first)
    end

    it "raises a custom error when the fixture file does not exist" do
      registry = described_class.new(configuration)

      expect do
        registry.add("does/not_exist")
      end.to raise_error(
        FixtureKit::FixtureDefinitionNotFound,
        /Could not find fixture definition file for 'does\/not_exist'/
      )
    end
  end
end
