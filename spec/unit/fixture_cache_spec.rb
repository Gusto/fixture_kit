# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Cache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_test").to_s }
  let(:fixture_name) { "test_fixture" }
  let(:fixture) { instance_double(FixtureKit::Fixture, name: fixture_name) }
  let(:definition) { instance_double(FixtureKit::Definition, evaluate: nil, exposed: {}) }
  let(:cache) { described_class.new(fixture, definition) }
  let(:runner) do
    FixtureKit::Runner.new.tap do |runner|
      runner.configuration.cache_path = cache_path
      runner.configuration.fixture_path = Rails.root.join("fixture_kit").to_s
      runner.configuration.isolator = pass_through_isolator
    end
  end

  let(:pass_through_isolator) do
    Class.new do
      def run(&block)
        block.call
      end
    end
  end

  before do
    allow(FixtureKit).to receive(:runner).and_return(runner)
    FileUtils.rm_rf(cache_path)
  end

  after do
    FileUtils.rm_rf(cache_path)
  end

  describe "#path" do
    it "returns the cache file path for the fixture" do
      expect(cache.path).to eq(File.join(cache_path, "test_fixture.json"))
    end

    it "handles nested fixture names" do
      nested_fixture = instance_double(FixtureKit::Fixture, name: "teams/basic")
      nested_cache = described_class.new(nested_fixture, definition)

      expect(nested_cache.path).to eq(File.join(cache_path, "teams/basic.json"))
    end
  end

  describe "#exists?" do
    it "returns false when no cache exists" do
      expect(cache.exists?).to be(false)
    end

    it "returns true when cache file exists" do
      FileUtils.mkdir_p(File.dirname(cache.path))
      File.write(cache.path, "{}")

      expect(cache.exists?).to be(true)
    end
  end

  describe "#save" do
    it "writes records and exposed data to disk" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-cache@example.com")
        expose(alice: alice)
      end
      fixture_cache = described_class.new(fixture, fixture_definition)

      fixture_cache.save

      expect(File.exist?(fixture_cache.path)).to be(true)
      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["records"]).to have_key("User")
      expect(data["exposed"]).to have_key("alice")
    end
  end

  describe "#load" do
    it "raises when cache is missing" do
      expect do
        cache.load
      end.to raise_error(FixtureKit::CacheMissingError, "Cache does not exist for fixture 'test_fixture'")
    end

    it "replays SQL and returns a repository of exposed records" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-replay@example.com")
        expose(alice: alice)
      end
      fixture_cache = described_class.new(fixture, fixture_definition)

      fixture_cache.save

      User.delete_all
      repository = fixture_cache.load

      expect(repository.alice).to be_a(User)
      expect(repository.alice.name).to eq("Alice")
    end
  end
end
