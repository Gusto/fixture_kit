# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Singleton do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_singleton_test").to_s }

  before do
    FileUtils.rm_rf(cache_path)
    FixtureKit::FixtureCache.clear_memory_cache
    FixtureKit.configuration.cache_path = cache_path
  end

  after do
    FileUtils.rm_rf(cache_path)
    FixtureKit::FixtureCache.clear_memory_cache
  end

  describe ".clear_cache" do
    before do
      # Set up memory cache
      FixtureKit::FixtureCache.memory_cache["fixture_a"] = { "records" => {} }
      FixtureKit::FixtureCache.memory_cache["fixture_b"] = { "records" => {} }

      # Set up disk cache
      FileUtils.mkdir_p(cache_path)
      File.write(File.join(cache_path, "fixture_a.json"), "{}")
      File.write(File.join(cache_path, "fixture_b.json"), "{}")
    end

    it "clears a specific fixture from both memory and disk" do
      FixtureKit.clear_cache("fixture_a")

      # Memory cache
      expect(FixtureKit::FixtureCache.memory_cache.key?("fixture_a")).to be(false)
      expect(FixtureKit::FixtureCache.memory_cache.key?("fixture_b")).to be(true)

      # Disk cache
      expect(File.exist?(File.join(cache_path, "fixture_a.json"))).to be(false)
      expect(File.exist?(File.join(cache_path, "fixture_b.json"))).to be(true)
    end

    it "clears all fixtures from both memory and disk when no argument given" do
      FixtureKit.clear_cache

      # Memory cache
      expect(FixtureKit::FixtureCache.memory_cache).to be_empty

      # Disk cache
      expect(Dir.exist?(cache_path)).to be(false)
    end
  end

  describe ".reset" do
    before do
      FixtureKit::FixtureCache.memory_cache["test_fixture"] = { "records" => {} }
    end

    it "clears memory cache" do
      FixtureKit.reset

      expect(FixtureKit::FixtureCache.memory_cache).to be_empty
    end
  end
end
