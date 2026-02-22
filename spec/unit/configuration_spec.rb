# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Configuration do
  describe "#isolator" do
    it "defaults to FixtureKit::Minitest::Isolator" do
      expect(described_class.new.isolator).to eq(FixtureKit::Minitest::Isolator)
    end

    it "returns an explicitly configured class" do
      custom_isolator_class = Class.new(FixtureKit::Isolator)
      configuration = described_class.new
      configuration.isolator = custom_isolator_class

      expect(configuration.isolator).to eq(custom_isolator_class)
    end
  end

  describe "#on_cache" do
    it "defaults to nil" do
      expect(described_class.new.on_cache).to be_nil
    end

    it "returns an explicitly configured proc" do
      callback = proc {}
      configuration = described_class.new
      configuration.on_cache = callback

      expect(configuration.on_cache).to eq(callback)
    end
  end
end
