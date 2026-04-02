# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Definition do
  describe "#extends" do
    it "stores parent fixture name for inherited definitions" do
      definition = described_class.new(extends: "teams/basic") {}

      expect(definition.extends).to eq("teams/basic")
    end
  end

  describe "#evaluate" do
    it "captures exposed records from the definition block" do
      definition = described_class.new do
        expose(alice: "alice")
      end

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ alice: "alice" })
    end

    it "supports helper methods from execution context" do
      helper_context = Class.new do
        def fixture_name
          "alice"
        end
      end.new

      definition = described_class.new do
        expose(alice: fixture_name)
      end

      definition.evaluate(helper_context)

      expect(definition.exposed).to eq({ alice: "alice" })
    end

    it "supports parent helper in execution context" do
      parent_repository = Struct.new(:owner).new("alice")
      definition = described_class.new do
        expose(owner: parent.owner)
      end

      definition.evaluate(Object.new, parent: parent_repository)

      expect(definition.exposed).to eq({ owner: "alice" })
    end
  end

  describe "#expose" do
    it "raises when the same name is exposed twice" do
      definition = described_class.new do
        expose(alice: "alice")
        expose(alice: "duplicate")
      end

      expect do
        definition.evaluate(Object.new)
      end.to raise_error(FixtureKit::DuplicateNameError, "Name alice already exposed")
    end

    it "accepts all JSON-compatible primitive types" do
      definition = described_class.new do
        expose(
          str: "hello",
          int: 42,
          yes: true,
          no: false,
          nothing: nil,
          hsh: { "key" => "value" },
          arr: [1, 2, 3]
        )
      end

      expect { definition.evaluate(Object.new) }.not_to raise_error
    end

    it "raises UnsupportedExposedType for unsupported types" do
      [
        [:active, :status, /Unsupported type Symbol for exposed name :status/],
        [Object.new, :thing, /Unsupported type Object for exposed name :thing/],
        [{ role: "admin" }, :metadata, /Unsupported hash key type Symbol in exposed name :metadata/],
        [{ "status" => :active }, :data, /Unsupported type Symbol for exposed name :data/],
        [["valid", :invalid], :items, /Unsupported type Symbol for exposed name :items/]
      ].each do |value, name, pattern|
        definition = described_class.new do
          expose(**{ name => value })
        end

        expect do
          definition.evaluate(Object.new)
        end.to raise_error(FixtureKit::UnsupportedExposedType, pattern)
      end
    end
  end
end
