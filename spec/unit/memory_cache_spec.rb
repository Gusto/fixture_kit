# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::MemoryCache do
  describe "#initialize" do
    it "stores data and exposed" do
      cache = described_class.new(
        data: { FixtureKit::ActiveRecordCoder => { "User" => "SQL" } },
        exposed: { alice: 1 }
      )

      expect(cache.data).to eq({ FixtureKit::ActiveRecordCoder => { "User" => "SQL" } })
      expect(cache.exposed).to eq({ alice: 1 })
    end

    it "is frozen after initialization" do
      cache = described_class.new(data: {}, exposed: {})

      expect(cache).to be_frozen
    end
  end
end
