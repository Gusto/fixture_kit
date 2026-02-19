# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FixtureCache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_test").to_s }
  let(:fixture_name) { "test_fixture" }
  let(:cache) { described_class.new(fixture_name, cache_path) }

  before do
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
      nested_cache = described_class.new("teams/basic", cache_path)
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
      cache1 = described_class.new(fixture_name, cache_path)
      cache1.load

      # Second load - should use memory cache
      cache2 = described_class.new(fixture_name, cache_path)

      # Delete the disk file to prove memory cache is used
      File.delete(cache.cache_file_path)

      expect(cache2.load).to be(true)
      expect(cache2.records).to eq(test_data["records"])
    end
  end

  describe "#save" do
    let(:records) { { "User" => "INSERT INTO users VALUES (1, 'Alice')" } }
    let(:exposed) { { "alice" => { "model" => "User", "id" => 1 } } }

    it "writes data to disk" do
      cache.save(records, exposed)

      expect(File.exist?(cache.cache_file_path)).to be(true)

      saved_data = JSON.parse(File.read(cache.cache_file_path))
      expect(saved_data["records"]).to eq(records)
      expect(saved_data["exposed"]).to eq(exposed)
    end

    it "stores data in memory cache" do
      cache.save(records, exposed)

      expect(described_class.memory_cache[fixture_name]).to eq({
        "digest" => nil,
        "records" => records,
        "exposed" => exposed
      })
    end

    it "stores digest when provided" do
      cache.save(records, exposed, digest: "abc123")

      expect(cache.digest).to eq("abc123")
      expect(described_class.memory_cache[fixture_name]["digest"]).to eq("abc123")

      saved_data = JSON.parse(File.read(cache.cache_file_path))
      expect(saved_data["digest"]).to eq("abc123")
    end

    it "creates nested directories for nested fixture names" do
      nested_cache = described_class.new("teams/engineering/backend", cache_path)
      nested_cache.save(records, exposed)

      expect(File.exist?(nested_cache.cache_file_path)).to be(true)
    end

    it "sets instance attributes" do
      cache.save(records, exposed)

      expect(cache.records).to eq(records)
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

  describe ".in_memory?" do
    it "returns true when fixture is in memory cache" do
      described_class.memory_cache["my_fixture"] = { "records" => {} }

      expect(described_class.in_memory?("my_fixture")).to be(true)
    end

    it "returns false when fixture is not in memory cache" do
      expect(described_class.in_memory?("nonexistent")).to be(false)
    end

    it "handles symbol fixture names" do
      described_class.memory_cache["my_fixture"] = { "records" => {} }

      expect(described_class.in_memory?(:my_fixture)).to be(true)
    end
  end

  describe ".compute_digest" do
    let(:test_file) { File.join(cache_path, "test_file.rb") }

    before do
      FileUtils.mkdir_p(cache_path)
    end

    it "returns MD5 digest of file contents" do
      File.write(test_file, "hello world")

      digest = described_class.compute_digest(test_file)

      expect(digest).to eq(Digest::MD5.hexdigest("hello world"))
    end

    it "returns different digest for different contents" do
      File.write(test_file, "content1")
      digest1 = described_class.compute_digest(test_file)

      File.write(test_file, "content2")
      digest2 = described_class.compute_digest(test_file)

      expect(digest1).not_to eq(digest2)
    end

    it "returns nil for nil path" do
      expect(described_class.compute_digest(nil)).to be_nil
    end

    it "returns nil for nonexistent file" do
      expect(described_class.compute_digest("/nonexistent/path.rb")).to be_nil
    end
  end

  describe "#digest" do
    let(:test_data_with_digest) do
      {
        "digest" => "abc123def456",
        "records" => { "User" => "INSERT INTO users VALUES (1, 'Alice')" },
        "exposed" => { "alice" => { "model" => "User", "id" => 1 } }
      }
    end

    it "loads digest from disk cache" do
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(test_data_with_digest))

      cache.load

      expect(cache.digest).to eq("abc123def456")
    end

    it "loads digest from memory cache" do
      described_class.memory_cache[fixture_name] = test_data_with_digest

      cache.load

      expect(cache.digest).to eq("abc123def456")
    end

    it "handles missing digest in cache (nil)" do
      data_without_digest = {
        "records" => { "User" => "INSERT" },
        "exposed" => {}
      }
      FileUtils.mkdir_p(cache_path)
      File.write(cache.cache_file_path, JSON.generate(data_without_digest))

      cache.load

      expect(cache.digest).to be_nil
    end
  end
end
