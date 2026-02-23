# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Registry do
  let(:runner) do
    FixtureKit::Runner.new.tap do |runner|
      runner.configuration.fixture_path = Rails.root.join("fixture_kit").to_s
    end
  end

  before do
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  describe "#add" do
    it "loads and returns a fixture by name for a scope" do
      registry = described_class.new
      scope = Class.new

      fixture = registry.add(scope, "project_management")

      expect(fixture).to be_a(FixtureKit::Fixture)
      expect(fixture.identifier).to eq("project_management")
    end

    it "reuses the same named fixture instance across different scopes" do
      registry = described_class.new
      first_scope = Class.new
      second_scope = Class.new

      first = registry.add(first_scope, "project_management")
      second = registry.add(second_scope, "project_management")

      expect(second).to equal(first)
    end

    it "creates an anonymous fixture from a definition block" do
      registry = described_class.new
      scope = Class.new

      fixture = registry.add(scope, proc { expose(example: "record") })

      expect(fixture).to be_a(FixtureKit::Fixture)
      expect(fixture.identifier).to equal(scope)
    end

    it "raises when declaring multiple fixtures for the same class scope" do
      registry = described_class.new
      scope = Class.new
      registry.add(scope, "project_management")

      expect do
        registry.add(scope, "teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same context"
      )
    end

    it "raises when declaring multiple fixtures for the same example group scope" do
      registry = described_class.new
      scope = Class.new do
        def self.metadata
          { location: "spec/models/user_spec.rb:3" }
        end
      end
      registry.add(scope, "project_management")

      expect do
        registry.add(scope, "teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same context"
      )
    end

    it "raises a custom error when the fixture file does not exist" do
      registry = described_class.new
      scope = Class.new

      expect do
        registry.add(scope, "does/not_exist")
      end.to raise_error(
        FixtureKit::FixtureDefinitionNotFound,
        /cannot find fixture definition file for 'does\/not_exist'/
      )
    end

    it "raises when an unsupported declaration type is provided" do
      registry = described_class.new
      scope = Class.new

      expect do
        registry.add(scope, nil)
      end.to raise_error(
        FixtureKit::InvalidFixtureDeclaration,
        "unsupported fixture declaration type: NilClass"
      )
    end
  end
end
