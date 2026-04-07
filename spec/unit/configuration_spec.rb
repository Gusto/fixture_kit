# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Configuration do
  describe "#callbacks" do
    it "returns a callback registry" do
      expect(described_class.new.callbacks).to be_a(FixtureKit::Callbacks)
    end
  end

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
    it "defaults to an empty callback list" do
      expect(described_class.new.on_cache_save).to eq([])
    end

    it "registers and runs callbacks in order" do
      configuration = described_class.new
      callback_one = spy("callback_one")
      callback_two = spy("callback_two")
      cache = double("cache")

      configuration.on_cache_save { |c| callback_one.call(c) }
      configuration.on_cache_save { |c| callback_two.call(c) }

      expect(callback_one).to receive(:call).with(cache).ordered
      expect(callback_two).to receive(:call).with(cache).ordered

      configuration.callbacks.run(:cache_save, cache)
    end
  end

  describe "#on_cache_saved" do
    it "defaults to an empty callback list" do
      expect(described_class.new.on_cache_saved).to eq([])
    end

    it "registers and runs callbacks in order with cache and duration" do
      configuration = described_class.new
      callback_one = spy("callback_one")
      callback_two = spy("callback_two")
      cache = double("cache")

      configuration.on_cache_saved { |c, duration| callback_one.call(c, duration) }
      configuration.on_cache_saved { |c, duration| callback_two.call(c, duration) }

      expect(callback_one).to receive(:call).with(cache, 0.25).ordered
      expect(callback_two).to receive(:call).with(cache, 0.25).ordered

      configuration.callbacks.run(:cache_saved, cache, 0.25)
    end
  end

  describe "#on_cache_mount" do
    it "defaults to an empty callback list" do
      expect(described_class.new.on_cache_mount).to eq([])
    end

    it "registers and runs callbacks in order" do
      configuration = described_class.new
      callback_one = spy("callback_one")
      callback_two = spy("callback_two")
      cache = double("cache")

      configuration.on_cache_mount { |c| callback_one.call(c) }
      configuration.on_cache_mount { |c| callback_two.call(c) }

      expect(callback_one).to receive(:call).with(cache).ordered
      expect(callback_two).to receive(:call).with(cache).ordered

      configuration.callbacks.run(:cache_mount, cache)
    end
  end

  describe "#on_cache_mounted" do
    it "defaults to an empty callback list" do
      expect(described_class.new.on_cache_mounted).to eq([])
    end

    it "registers and runs callbacks in order with cache and duration" do
      configuration = described_class.new
      callback_one = spy("callback_one")
      callback_two = spy("callback_two")
      cache = double("cache")

      configuration.on_cache_mounted { |c, duration| callback_one.call(c, duration) }
      configuration.on_cache_mounted { |c, duration| callback_two.call(c, duration) }

      expect(callback_one).to receive(:call).with(cache, 0.15).ordered
      expect(callback_two).to receive(:call).with(cache, 0.15).ordered

      configuration.callbacks.run(:cache_mounted, cache, 0.15)
    end
  end
end
