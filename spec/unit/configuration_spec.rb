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

  describe "#adapter" do
    it "defaults to FixtureKit::MinitestAdapter" do
      expect(described_class.new.adapter).to eq(FixtureKit::MinitestAdapter)
    end

    it "returns an explicitly configured class and options" do
      custom_adapter_class = Class.new(FixtureKit::Adapter)
      configuration = described_class.new
      configuration.adapter(custom_adapter_class, option1: "value1")

      expect(configuration.adapter).to eq(custom_adapter_class)
      expect(configuration.adapter_options).to eq(option1: "value1")
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
