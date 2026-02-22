# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Definition do
  describe "#evaluate" do
    it "captures exposed records from the definition block" do
      definition = described_class.new do
        expose(alice: "alice")
      end

      definition.evaluate

      expect(definition.exposed).to eq({ alice: "alice" })
    end
  end

  describe "#expose" do
    it "raises when the same name is exposed twice" do
      definition = described_class.new do
        expose(alice: "alice")
        expose(alice: "duplicate")
      end

      expect do
        definition.evaluate
      end.to raise_error(FixtureKit::DuplicateNameError, "Name alice already exposed")
    end
  end
end
