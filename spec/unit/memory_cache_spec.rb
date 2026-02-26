# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::MemoryCache do
  describe "#initialize" do
    it "stores records and exposed data" do
      cache = described_class.new(records: { "User" => "SQL" }, exposed: { alice: 1 })

      expect(cache.records).to eq({ "User" => "SQL" })
      expect(cache.exposed).to eq({ alice: 1 })
    end

    it "is frozen after initialization" do
      cache = described_class.new(records: {}, exposed: {})

      expect(cache).to be_frozen
    end
  end

  describe "#to_h" do
    it "returns a hash of records and exposed" do
      cache = described_class.new(
        records: { "User" => "INSERT INTO users VALUES (1)" },
        exposed: { alice: { "User" => 1 } }
      )

      expect(cache.to_h).to eq({
        records: { "User" => "INSERT INTO users VALUES (1)" },
        exposed: { alice: { "User" => 1 } }
      })
    end
  end
end
