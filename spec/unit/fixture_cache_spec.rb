# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FixtureCache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_test").to_s }
  let(:fixture_path) { Rails.root.join("spec/fixture_kit").to_s }
  let(:fixture_name) { "test_fixture" }
  let(:cache) { described_class.new(fixture_name) }

  before do
    # Configure FixtureKit to use test paths
    FixtureKit.configure do |config|
      config.cache_path = cache_path
      config.fixture_path = fixture_path
    end

    # Clear both disk and memory cache before each test
    FileUtils.rm_rf(cache_path)
    described_class.clear_memory_cache
  end

  after do
    FileUtils.rm_rf(cache_path)
    described_class.clear_memory_cache
  end

  describe "#cache_file_path" do
    it "returns the correct path" do
      expect(cache.cache_file_path).to eq(File.join(cache_path, "test_fixture.json"))
    end

    it "handles nested fixture names" do
      nested_cache = described_class.new("teams/basic")
      expect(nested_cache.cache_file_path).to eq(File.join(cache_path, "teams/basic.json"))
    end
  end

  describe "#exists?" do
    it "returns false when neither memory nor disk cache exists" do
      expect(cache.exists?).to be(false)
    end

    it "returns true when disk cache exists" do
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, "{}")
      expect(cache.exists?).to be(true)
    end

    it "returns true when memory cache exists" do
      described_class.memory_cache[fixture_name] = { "records" => {}, "exposed" => {} }
      expect(cache.exists?).to be(true)
    end

    it "returns true when memory cache exists even without disk cache" do
      described_class.memory_cache[fixture_name] = { "records" => {}, "exposed" => {} }
      expect(File.exist?(cache.cache_file_path)).to be(false)
      expect(cache.exists?).to be(true)
    end
  end

  describe "#load" do
    let(:test_data) do
      {
        "records" => { "User" => "INSERT INTO users VALUES (1, 'Alice')" },
        "exposed" => { "alice" => { "model" => "User", "id" => 1 } }
      }
    end

    it "returns false when cache does not exist" do
      expect(cache.load).to be(false)
    end

    it "loads data from disk cache" do
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(test_data))

      expect(cache.load).to be(true)
      expect(cache.records).to eq(test_data["records"])
      expect(cache.exposed).to eq(test_data["exposed"])
    end

    it "stores data in memory cache after loading from disk" do
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(test_data))

      cache.load

      expect(described_class.memory_cache[fixture_name]).to eq(test_data)
    end

    it "loads data from memory cache without reading disk" do
      described_class.memory_cache[fixture_name] = test_data

      # No disk file exists
      expect(File.exist?(cache.cache_file_path)).to be(false)

      expect(cache.load).to be(true)
      expect(cache.records).to eq(test_data["records"])
      expect(cache.exposed).to eq(test_data["exposed"])
    end

    it "prefers memory cache over disk cache" do
      memory_data = {
        "records" => { "User" => "MEMORY INSERT" },
        "exposed" => { "memory_user" => { "model" => "User", "id" => 99 } }
      }
      disk_data = {
        "records" => { "User" => "DISK INSERT" },
        "exposed" => { "disk_user" => { "model" => "User", "id" => 1 } }
      }

      # Set up both caches
      described_class.memory_cache[fixture_name] = memory_data
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(disk_data))

      cache.load

      # Should use memory cache
      expect(cache.records).to eq(memory_data["records"])
      expect(cache.exposed).to eq(memory_data["exposed"])
    end

    it "only parses JSON once across multiple loads" do
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(test_data))

      # First load - reads from disk
      cache1 = described_class.new(fixture_name)
      cache1.load

      # Second load - should use memory cache
      cache2 = described_class.new(fixture_name)

      # Delete the disk file to prove memory cache is used
      File.delete(cache.cache_file_path)

      expect(cache2.load).to be(true)
      expect(cache2.records).to eq(test_data["records"])
    end
  end

  describe "#save" do
    let(:exposed) { { "alice" => { "model" => "User", "id" => 1 } } }

    # Use empty models_with_connections for basic save tests
    # Full integration is tested in integration specs
    let(:models_with_connections) { {} }

    it "writes data to disk" do
      cache.save(models_with_connections: models_with_connections, exposed_mapping: exposed)

      expect(File.exist?(cache.cache_file_path)).to be(true)

      saved_data = JSON.parse(File.read(cache.cache_file_path))
      expect(saved_data["records"]).to eq({})
      expect(saved_data["exposed"]).to eq(exposed)
    end

    it "stores data in memory cache" do
      cache.save(models_with_connections: models_with_connections, exposed_mapping: exposed)

      expect(described_class.memory_cache[fixture_name]).to eq({
        "records" => {},
        "exposed" => exposed
      })
    end

    it "creates nested directories for nested fixture names" do
      nested_cache = described_class.new("teams/engineering/backend")
      nested_cache.save(models_with_connections: models_with_connections, exposed_mapping: exposed)

      expect(File.exist?(nested_cache.cache_file_path)).to be(true)
    end

    it "sets instance attributes" do
      cache.save(models_with_connections: models_with_connections, exposed_mapping: exposed)

      expect(cache.records).to eq({})
      expect(cache.exposed).to eq(exposed)
    end
  end

  describe ".clear_memory_cache" do
    before do
      described_class.memory_cache["fixture_a"] = { "records" => {} }
      described_class.memory_cache["fixture_b"] = { "records" => {} }
    end

    it "clears a specific fixture from memory cache" do
      described_class.clear_memory_cache("fixture_a")

      expect(described_class.memory_cache.key?("fixture_a")).to be(false)
      expect(described_class.memory_cache.key?("fixture_b")).to be(true)
    end

    it "clears all fixtures from memory cache when no argument given" do
      described_class.clear_memory_cache

      expect(described_class.memory_cache).to be_empty
    end

    it "handles symbol fixture names" do
      described_class.clear_memory_cache(:fixture_a)

      expect(described_class.memory_cache.key?("fixture_a")).to be(false)
    end
  end

  describe ".clear" do
    before do
      # Set up memory cache
      described_class.memory_cache["fixture_a"] = { "records" => {} }
      described_class.memory_cache["fixture_b"] = { "records" => {} }

      # Set up disk cache
      FileUtils.mkdir_p(cache_path)
      File.write(File.join(cache_path, "fixture_a.json"), "{}")
      File.write(File.join(cache_path, "fixture_b.json"), "{}")
    end

    it "clears a specific fixture from both memory and disk" do
      described_class.clear("fixture_a")

      # Memory cache
      expect(described_class.memory_cache.key?("fixture_a")).to be(false)
      expect(described_class.memory_cache.key?("fixture_b")).to be(true)

      # Disk cache
      expect(File.exist?(File.join(cache_path, "fixture_a.json"))).to be(false)
      expect(File.exist?(File.join(cache_path, "fixture_b.json"))).to be(true)
    end

    it "clears all fixtures from both memory and disk when no fixture_name given" do
      described_class.clear

      # Memory cache
      expect(described_class.memory_cache).to be_empty

      # Disk cache
      expect(Dir.exist?(cache_path)).to be(false)
    end
  end

  describe ".pregenerate_all" do
    before do
      described_class.clear
    end

    it "generates caches for all fixtures" do
      project_cache = File.join(cache_path, "project_management.json")
      teams_cache = File.join(cache_path, "teams/basic.json")

      expect(File.exist?(project_cache)).to be(false)
      expect(File.exist?(teams_cache)).to be(false)

      described_class.pregenerate_all

      expect(File.exist?(project_cache)).to be(true)
      expect(File.exist?(teams_cache)).to be(true)
    end

    it "does not persist data to database" do
      # Database should be empty before
      expect(User.count).to eq(0)
      expect(ActivityLog.count).to eq(0)
      expect(TimeEntry.count).to eq(0)

      described_class.pregenerate_all

      # Database should still be empty (transactions rolled back)
      expect(User.count).to eq(0)
      expect(ActivityLog.count).to eq(0)
      expect(TimeEntry.count).to eq(0)

      # But caches should exist
      project_cache = File.join(cache_path, "project_management.json")
      expect(File.exist?(project_cache)).to be(true)
    end

    it "regenerates caches even if they already exist" do
      # Generate cache
      described_class.pregenerate_all

      project_cache = File.join(cache_path, "project_management.json")

      # Corrupt the cache file with invalid content
      File.write(project_cache, '{"records": {}, "exposed": {}}')

      # Pregenerate again - should overwrite with valid content
      described_class.pregenerate_all

      # Cache should have actual records now
      cache_data = JSON.parse(File.read(project_cache))
      expect(cache_data["records"]).to have_key("User")
      expect(cache_data["exposed"]).to have_key("alice")
    end
  end
end
