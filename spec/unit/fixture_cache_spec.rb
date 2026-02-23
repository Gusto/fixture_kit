# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Cache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_test").to_s }
  let(:fixture_name) { "test_fixture" }
  let(:definition) { instance_double(FixtureKit::Definition, evaluate: nil, exposed: {}) }
  let(:fixture) { instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: definition) }
  let(:cache) { described_class.new(fixture) }
  let(:runner) do
    FixtureKit::Runner.new.tap do |runner|
      runner.configuration.cache_path = cache_path
      runner.configuration.fixture_path = Rails.root.join("fixture_kit").to_s
      runner.configuration.adapter(pass_through_adapter)
    end
  end

  let(:pass_through_adapter) do
    Class.new(FixtureKit::Adapter) do
      def execute(&block)
        block.call
      end

      def identifier_for(identifier)
        normalized_scope = identifier.to_s.sub(/\ARSpec::ExampleGroups::/, "")
        ActiveSupport::Inflector.underscore(normalized_scope)
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
      nested_fixture = instance_double(FixtureKit::Fixture, identifier: "teams/basic", definition: definition)
      nested_cache = described_class.new(nested_fixture)

      expect(nested_cache.path).to eq(File.join(cache_path, "teams/basic.json"))
    end

    it "normalizes class identifiers for anonymous fixtures" do
      anonymous_scope = Class.new
      allow(anonymous_scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_fixture = instance_double(FixtureKit::Fixture, identifier: anonymous_scope, definition: anonymous_definition)
      anonymous_cache = described_class.new(anonymous_fixture)

      expect(anonymous_cache.path).to eq(File.join(cache_path, "_anonymous/foo/with_fixture_kit/hello.json"))
    end
  end

  describe "#identifier" do
    it "returns the string identifier for named fixtures" do
      expect(cache.identifier).to eq("test_fixture")
    end

    it "normalizes scope-class identifiers for anonymous fixtures" do
      anonymous_scope = Class.new
      allow(anonymous_scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_fixture = instance_double(FixtureKit::Fixture, identifier: anonymous_scope, definition: anonymous_definition)
      anonymous_cache = described_class.new(anonymous_fixture)

      expect(anonymous_cache.identifier).to eq("_anonymous/foo/with_fixture_kit/hello")
    end

    it "memoizes normalized anonymous identifiers" do
      anonymous_scope = Class.new
      allow(anonymous_scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_fixture = instance_double(FixtureKit::Fixture, identifier: anonymous_scope, definition: anonymous_definition)
      anonymous_cache = described_class.new(anonymous_fixture)

      anonymous_cache.identifier
      anonymous_cache.identifier

      expect(anonymous_scope).to have_received(:to_s).once
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
      fixture_double = instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: fixture_definition)
      fixture_cache = described_class.new(fixture_double)

      fixture_cache.save

      expect(File.exist?(fixture_cache.path)).to be(true)
      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["records"]).to have_key("User")
      expect(data["exposed"]).to have_key("alice")
    end

    it "tracks update-only writes from sql.active_record payload names" do
      user = User.create!(name: "Alice", email: "alice-update@example.com")

      fixture_definition = FixtureKit::Definition.new do
        user = User.find_by!(email: "alice-update@example.com")
        user.update!(name: "Alice Updated")
        expose(alice: user)
      end

      fixture_double = instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: fixture_definition)
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["records"]).to have_key("User")

      User.delete_all
      repository = fixture_cache.load
      expect(repository.alice.id).to eq(user.id)
      expect(repository.alice.name).to eq("Alice Updated")
    end

    it "tracks delete-only writes from sql.active_record payload names" do
      User.create!(name: "Alice", email: "alice-delete@example.com")
      User.create!(name: "Bob", email: "bob-delete@example.com")

      fixture_definition = FixtureKit::Definition.new do
        User.find_by!(email: "bob-delete@example.com").destroy!
        expose(alice: User.find_by!(email: "alice-delete@example.com"))
      end

      fixture_double = instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: fixture_definition)
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["records"]).to have_key("User")

      User.delete_all
      repository = fixture_cache.load
      expect(User.count).to eq(1)
      expect(repository.alice.email).to eq("alice-delete@example.com")
    end

    it "stores nil insert sql when a changed table becomes empty" do
      User.create!(name: "Alice", email: "alice-empty@example.com")

      fixture_definition = FixtureKit::Definition.new do
        User.find_by!(email: "alice-empty@example.com").destroy!
      end

      fixture_double = instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: fixture_definition)
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["records"]["User"]).to be_nil

      User.create!(name: "Temporary", email: "temporary@example.com")
      fixture_cache.load
      expect(User.count).to eq(0)
    end
  end

  describe "#load" do
    it "documents that connection execute_batch is currently private" do
      connection = User.connection

      expect(connection.respond_to?(:execute_batch, true)).to be(true)
      expect(connection.private_methods).to include(:execute_batch)
      expect(connection.public_methods).not_to include(:execute_batch)
    end

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
      fixture_double = instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: fixture_definition)
      fixture_cache = described_class.new(fixture_double)

      fixture_cache.save

      User.delete_all
      repository = fixture_cache.load

      expect(repository.alice).to be_a(User)
      expect(repository.alice.name).to eq("Alice")
    end
  end
end
