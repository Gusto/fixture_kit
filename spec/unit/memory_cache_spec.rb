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

  describe "#data_for" do
    it "returns the data stored for a coder class" do
      cache = described_class.new(
        data: { FixtureKit::ActiveRecordCoder => { "User" => "SQL" } },
        exposed: {}
      )

      expect(cache.data_for(FixtureKit::ActiveRecordCoder)).to eq({ "User" => "SQL" })
    end

    it "raises an actionable error when the cache predates a coder" do
      # A cache written before this coder was registered has no entry for it.
      # Rather than an opaque KeyError, callers should learn the cache is stale
      # and how to fix it — naming the coder and pointing to regeneration.
      cache = described_class.new(data: {}, exposed: {})

      expect { cache.data_for(FixtureKit::ActiveRecordCoder) }
        .to raise_error(FixtureKit::MissingCoderDataError) do |error|
          expect(error.message).to include("FixtureKit::ActiveRecordCoder")
          expect(error.message).to match(/regenerate/i)
        end
    end
  end
end
