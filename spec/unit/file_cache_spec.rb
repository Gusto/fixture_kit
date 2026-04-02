# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FileCache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_file_cache_test").to_s }
  let(:file_path) { File.join(cache_path, "test_fixture.json") }
  let(:file_cache) { described_class.new(file_path) }

  before do
    FileUtils.rm_rf(cache_path)
  end

  after do
    FileUtils.rm_rf(cache_path)
  end

  describe "#path" do
    it "returns the path provided at initialization" do
      expect(file_cache.path).to eq(file_path)
    end
  end

  describe "#exists?" do
    it "returns false when the file does not exist" do
      expect(file_cache.exists?).to be(false)
    end

    it "returns true when the file exists" do
      FileUtils.mkdir_p(cache_path)
      File.write(file_path, "{}")

      expect(file_cache.exists?).to be(true)
    end
  end

  describe "#write and #read" do
    it "round-trips MemoryCache with AR records through JSON on disk" do
      data = FixtureKit::MemoryCache.new(
        records: { User => "INSERT INTO users (id, name) VALUES (1, 'Alice')" },
        exposed: { alice: { "_model" => "User", "_id" => 1 } }
      )

      file_cache.write(data)

      expect(File.exist?(file_path)).to be(true)
      result = file_cache.read
      expect(result).to be_a(FixtureKit::MemoryCache)
      expect(result.records).to eq({ User => "INSERT INTO users (id, name) VALUES (1, 'Alice')" })
      expect(result.exposed).to eq({ alice: { "_model" => "User", "_id" => 1 } })
    end

    it "round-trips MemoryCache with nil sql values" do
      data = FixtureKit::MemoryCache.new(
        records: { User => nil },
        exposed: {}
      )

      file_cache.write(data)
      result = file_cache.read

      expect(result.records).to eq({ User => nil })
    end

    it "round-trips mixed AR, primitive, and nested exposed values" do
      data = FixtureKit::MemoryCache.new(
        records: { User => "INSERT INTO users ..." },
        exposed: {
          alice: { "_model" => "User", "_id" => 1 },
          users: [{ "_model" => "User", "_id" => 1 }, { "_model" => "User", "_id" => 2 }],
          label: "admin",
          count: 42,
          active: true,
          deleted: false,
          nothing: nil,
          metadata: { "role" => "admin" },
          tags: [1, 2, 3],
          nested: { "user" => { "_model" => "User", "_id" => 1 }, "label" => "test" }
        }
      )

      file_cache.write(data)
      result = file_cache.read

      expect(result.exposed).to eq(data.exposed.transform_keys(&:to_s).transform_keys(&:to_sym))
    end

    it "creates intermediate directories" do
      nested_path = File.join(cache_path, "nested", "deep", "fixture.json")
      nested_file_cache = described_class.new(nested_path)
      data = FixtureKit::MemoryCache.new(records: {}, exposed: {})

      nested_file_cache.write(data)

      expect(File.exist?(nested_path)).to be(true)
    end
  end

  describe "#serialize_exposed" do
    it "converts ActiveRecord instances to _model/_id pairs" do
      user = User.create!(name: "Alice", email: "alice-file-cache@example.com")

      result = file_cache.serialize_exposed({ alice: user })

      expect(result).to eq({ alice: { "_model" => "User", "_id" => user.id } })
    end

    it "passes through primitives as-is" do
      result = file_cache.serialize_exposed({
        label: "admin",
        count: 42,
        active: true,
        deleted: false,
        nothing: nil,
        metadata: { "role" => "admin" },
        tags: ["ruby", "rails"]
      })

      expect(result).to eq({
        label: "admin",
        count: 42,
        active: true,
        deleted: false,
        nothing: nil,
        metadata: { "role" => "admin" },
        tags: ["ruby", "rails"]
      })
    end

    it "recursively converts ActiveRecord instances in nested structures" do
      user = User.create!(name: "Alice", email: "alice-nested@example.com")
      model_hash = { "_model" => "User", "_id" => user.id }

      result = file_cache.serialize_exposed({
        users: [user, user],
        data: { "user" => user, "label" => "admin" },
        deep: { "nested" => { "user" => user } },
        mixed: ["tag", user]
      })

      expect(result).to eq({
        users: [model_hash, model_hash],
        data: { "user" => model_hash, "label" => "admin" },
        deep: { "nested" => { "user" => model_hash } },
        mixed: ["tag", model_hash]
      })
    end
  end
end
