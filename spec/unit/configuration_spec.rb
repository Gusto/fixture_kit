# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Configuration do
  describe "#fixture_path" do
    it "defaults to fixture_kit" do
      expect(described_class.new.fixture_path).to eq("fixture_kit")
    end

    it "returns an explicitly configured path" do
      configuration = described_class.new
      configuration.fixture_path = "spec/fixture_kit"

      expect(configuration.fixture_path).to eq("spec/fixture_kit")
    end
  end

  describe "#isolator" do
    it "defaults to FixtureKit::MinitestIsolator" do
      expect(described_class.new.isolator).to eq(FixtureKit::MinitestIsolator)
    end

    it "returns an explicitly configured class" do
      custom_isolator_class = Class.new(FixtureKit::Isolator)
      configuration = described_class.new
      configuration.isolator = custom_isolator_class

      expect(configuration.isolator).to eq(custom_isolator_class)
    end
  end

  describe "#on_cache_save" do
    it "defaults to nil" do
      expect(described_class.new.on_cache_save).to be_nil
    end

    it "returns an explicitly configured proc" do
      callback = proc {}
      configuration = described_class.new
      configuration.on_cache_save = callback

      expect(configuration.on_cache_save).to eq(callback)
    end
  end

  describe "#on_cache_mount" do
    it "defaults to nil" do
      expect(described_class.new.on_cache_mount).to be_nil
    end

    it "returns an explicitly configured proc" do
      callback = proc {}
      configuration = described_class.new
      configuration.on_cache_mount = callback

      expect(configuration.on_cache_mount).to eq(callback)
    end
  end
end
