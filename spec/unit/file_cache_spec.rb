# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FileCache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_file_cache_test").to_s }
  let(:file_path) { File.join(cache_path, "test_fixture.json") }
  let(:file_cache) { described_class.new(file_path) }
  let(:stop_path) { "#{cache_path}.stop" }

  before do
    FileUtils.rm_rf(cache_path)
    FileUtils.rm_f(stop_path)
  end

  after do
    FileUtils.rm_rf(cache_path)
    FileUtils.rm_f(stop_path)
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
    it "round-trips MemoryCache through JSON on disk" do
      data = FixtureKit::MemoryCache.new(
        data: { FixtureKit::ActiveRecordCoder => { User => "INSERT INTO users (id, name) VALUES (1, 'Alice')" } },
        exposed: { alice: { User => 1 } }
      )

      file_cache.write(data)

      expect(File.exist?(file_path)).to be(true)
      result = file_cache.read
      expect(result).to be_a(FixtureKit::MemoryCache)
      expect(result.data[FixtureKit::ActiveRecordCoder]).to eq({ User => "INSERT INTO users (id, name) VALUES (1, 'Alice')" })
      expect(result.exposed).to eq({ alice: { User => 1 } })
    end

    it "round-trips MemoryCache with nil sql values" do
      data = FixtureKit::MemoryCache.new(
        data: { FixtureKit::ActiveRecordCoder => { User => nil } },
        exposed: {}
      )

      file_cache.write(data)
      result = file_cache.read

      expect(result.data[FixtureKit::ActiveRecordCoder]).to eq({ User => nil })
    end

    it "round-trips MemoryCache with array exposed values" do
      data = FixtureKit::MemoryCache.new(
        data: { FixtureKit::ActiveRecordCoder => {} },
        exposed: { users: [{ User => 1 }, { User => 2 }] }
      )

      file_cache.write(data)
      result = file_cache.read

      expect(result.exposed).to eq({ users: [{ User => 1 }, { User => 2 }] })
    end

    it "creates intermediate directories" do
      nested_path = File.join(cache_path, "nested", "deep", "fixture.json")
      nested_file_cache = described_class.new(nested_path)
      data = FixtureKit::MemoryCache.new(data: {}, exposed: {})

      nested_file_cache.write(data)

      expect(File.exist?(nested_path)).to be(true)
    end

    it "leaves nothing but the cache file behind" do
      file_cache.write(FixtureKit::MemoryCache.new(data: {}, exposed: {}))

      expect(Dir.children(cache_path)).to contain_exactly("test_fixture.json")
    end

    # Processes share a cache directory whenever the cache outlives the process
    # that wrote it: a warm-up run, a preserved cache picked up by a second
    # suite, workers pointed at one `cache_path`. A reader that catches a
    # truncate-then-fill write reads a prefix of the JSON and blames the cache,
    # which looks like corruption rather than a race.
    it "does not expose a partially written file to a concurrent reader" do
      skip "fork is not supported on this platform" unless Process.respond_to?(:fork)

      # Large enough that a truncate-then-fill write leaves a window a reader
      # can land in; small enough that a hundred rewrites stay quick.
      data = FixtureKit::MemoryCache.new(
        data: { FixtureKit::ActiveRecordCoder => { User => "INSERT INTO users (id, name) VALUES (1, '#{"a" * 500_000}')" } },
        exposed: { alice: { User => 1 } }
      )
      file_cache.write(data)

      reader = fork do
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
        torn = false
        until File.exist?(stop_path) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          begin
            JSON.parse(File.read(file_path))
          rescue JSON::ParserError
            torn = true
            break
          end
        end
        exit!(torn ? 1 : 0)
      end

      begin
        100.times { file_cache.write(data) }
      ensure
        FileUtils.touch(stop_path)
      end
      _, status = Process.waitpid2(reader)

      expect(status.exitstatus).to eq(0), "a concurrent reader parsed a partially written cache file"
    end
  end
end
