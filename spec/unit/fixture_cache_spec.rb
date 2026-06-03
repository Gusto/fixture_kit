# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Cache do
  let(:cache_path) { Rails.root.join("tmp/cache/fixture_kit_test").to_s }
  let(:fixture_name) { "test_fixture" }
  let(:definition) { instance_double(FixtureKit::Definition, evaluate: nil, exposed: {}) }
  let(:fixture) do
    instance_double(FixtureKit::Fixture, identifier: fixture_name, definition: definition, parent: nil)
  end
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
      nested_fixture = instance_double(
        FixtureKit::Fixture,
        identifier: "teams/basic",
        definition: definition,
        parent: nil
      )
      nested_cache = described_class.new(nested_fixture)

      expect(nested_cache.path).to eq(File.join(cache_path, "teams/basic.json"))
    end

    it "normalizes class identifiers for anonymous fixtures" do
      anonymous_scope = Class.new
      allow(anonymous_scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_fixture = instance_double(
        FixtureKit::Fixture,
        identifier: anonymous_scope,
        definition: anonymous_definition,
        parent: nil
      )
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
      anonymous_fixture = instance_double(
        FixtureKit::Fixture,
        identifier: anonymous_scope,
        definition: anonymous_definition,
        parent: nil
      )
      anonymous_cache = described_class.new(anonymous_fixture)

      expect(anonymous_cache.identifier).to eq("_anonymous/foo/with_fixture_kit/hello")
    end

    it "memoizes normalized anonymous identifiers" do
      anonymous_scope = Class.new
      allow(anonymous_scope).to receive(:to_s).and_return("RSpec::ExampleGroups::Foo::WithFixtureKit::Hello")
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_fixture = instance_double(
        FixtureKit::Fixture,
        identifier: anonymous_scope,
        definition: anonymous_definition,
        parent: nil
      )
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
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)

      fixture_cache.save

      path = fixture_cache.path
      expect(File.exist?(path)).to be(true)
      data = JSON.parse(File.read(path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"]).to have_key("User")
      expect(data["exposed"]).to have_key("alice")
    end

    it "tracks update-only writes from sql.active_record payload names" do
      user = User.create!(name: "Alice", email: "alice-update@example.com")

      fixture_definition = FixtureKit::Definition.new do
        user = User.find_by!(email: "alice-update@example.com")
        user.update!(name: "Alice Updated")
        expose(alice: user)
      end

      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"]).to have_key("User")

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

      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"]).to have_key("User")

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

      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"]["User"]).to be_nil

      User.create!(name: "Temporary", email: "temporary@example.com")
      fixture_cache.load
      expect(User.count).to eq(0)
    end

    it "includes parent fixture model records when saving inherited fixtures" do
      parent_cache_data = FixtureKit::MemoryCache.new(
        data: { FixtureKit::ActiveRecordCoder => { User => nil } },
        exposed: {}
      )
      parent_cache = instance_double(FixtureKit::Cache, content: parent_cache_data)
      parent_fixture = instance_double(FixtureKit::Fixture, cache: parent_cache)
      allow(parent_fixture).to receive(:mount) do
        User.create!(name: "Parent Owner", email: "parent-owner@example.com")
        FixtureKit::Repository.new({})
      end

      child_definition = FixtureKit::Definition.new do
        owner = User.find_by!(email: "parent-owner@example.com")
        project = Project.create!(name: "Inherited Project", owner: owner)
        expose(project: project)
      end
      child_fixture = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: child_definition,
        parent: parent_fixture
      )
      child_cache = described_class.new(child_fixture)

      child_cache.save

      data = JSON.parse(File.read(child_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"].keys).to include("User", "Project")
    end
  end

  describe "parent model propagation via #mount (draft: no parent_data)" do
    # End-to-end exercise of the accumulator approach: a real parent cache is
    # saved, then "a fresh process" clears it from memory, and the child is
    # saved with the parent mounted from disk. The parent's models can only
    # reach the child cache via @replayed_models (recorded in
    # ActiveRecordCoder#mount), because the replayed INSERTs are tagged
    # "FixtureKit Insert" and the child's subscriber never sees them. None of
    # the child definitions below recreate the parent's models with a captured
    # write, so the assertions are load-bearing.
    def propagate(parent_id:, child_id:, parent_definition:, child_definition:)
      parent_fixture = instance_double(
        FixtureKit::Fixture, identifier: parent_id, definition: parent_definition, parent: nil
      )
      parent_cache = described_class.new(parent_fixture)
      parent_cache.save
      parent_cache.clear_memory # fresh process: @content nil, file on disk

      allow(parent_fixture).to receive(:cache).and_return(parent_cache)
      # Real mount: replays the parent's rows through ActiveRecordCoder#mount,
      # which records the models in @replayed_models.
      allow(parent_fixture).to receive(:mount) { parent_cache.load }

      child_fixture = instance_double(
        FixtureKit::Fixture, identifier: child_id, definition: child_definition, parent: parent_fixture
      )
      child_cache = described_class.new(child_fixture)
      child_cache.save

      JSON.parse(File.read(child_cache.path))["data"]["FixtureKit::ActiveRecordCoder"]
    end

    it "carries a basic parent model into the child cache across processes" do
      parent_definition = FixtureKit::Definition.new do
        User.create!(name: "Owner", email: "owner-c@example.com")
      end
      child_definition = FixtureKit::Definition.new do
        owner = User.find_by!(email: "owner-c@example.com")
        Project.create!(name: "Child Project", owner: owner)
      end

      data = propagate(
        parent_id: "parent_basic", child_id: "child_basic",
        parent_definition: parent_definition, child_definition: child_definition
      )

      expect(data.keys).to include("User", "Project")
    end

    it "collapses STI parent models to their base table and carries them" do
      parent_definition = FixtureKit::Definition.new do
        User.create!(name: "STI Owner", email: "sti-owner@example.com")
        Car.create!(name: "Beetle", year: 1968)
      end
      child_definition = FixtureKit::Definition.new do
        owner = User.find_by!(email: "sti-owner@example.com")
        Project.create!(name: "STI Child Project", owner: owner)
      end

      data = propagate(
        parent_id: "parent_sti", child_id: "child_sti",
        parent_definition: parent_definition, child_definition: child_definition
      )

      expect(data.keys).to include("User", "Vehicle", "Project")
      expect(data.keys).not_to include("Car") # collapsed to the base table model
    end

    it "carries parent models from a second connection pool" do
      parent_definition = FixtureKit::Definition.new do
        user = User.create!(name: "MP Owner", email: "mp-owner@example.com")
        ActivityLog.create!(external_user_id: user.id, action: "signed_in")
      end
      child_definition = FixtureKit::Definition.new do
        owner = User.find_by!(email: "mp-owner@example.com")
        Project.create!(name: "Multipool Child Project", owner: owner)
      end

      data = propagate(
        parent_id: "parent_multipool", child_id: "child_multipool",
        parent_definition: parent_definition, child_definition: child_definition
      )

      expect(data.keys).to include("User", "ActivityLog", "Project")
    end

    it "carries a parent model whose cached sql is nil (delete-only)" do
      parent_definition = FixtureKit::Definition.new do
        User.create!(name: "Del Owner", email: "del-owner@example.com")
        Phone.create!(name: "Doomed").destroy! # STI subclass; base table is gadgets
      end
      child_definition = FixtureKit::Definition.new do
        owner = User.find_by!(email: "del-owner@example.com")
        Project.create!(name: "Delete Child Project", owner: owner)
      end

      data = propagate(
        parent_id: "parent_delete", child_id: "child_delete",
        parent_definition: parent_definition, child_definition: child_definition
      )

      expect(data.keys).to include("User", "Gadget", "Project")
      expect(data["Gadget"]).to be_nil # carried forward even with no rows to insert
    end
  end

  describe "#clear_memory" do
    it "nils out @content" do
      cache.instance_variable_set(:@content, FixtureKit::MemoryCache.new(data: {}, exposed: {}))

      cache.clear_memory

      expect(cache.content).to be_nil
    end

    it "still reports exists? as true when file cache is present" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-clear@example.com")
        expose(alice: alice)
      end
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      fixture_cache.clear_memory

      expect(fixture_cache.content).to be_nil
      expect(fixture_cache.exists?).to be(true)
    end

    it "re-reads from file cache on next load" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-reread@example.com")
        expose(alice: alice)
      end
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      fixture_cache.clear_memory
      expect(fixture_cache.content).to be_nil

      User.delete_all
      repository = fixture_cache.load

      expect(fixture_cache.content).not_to be_nil
      expect(repository.alice).to be_a(User)
      expect(repository.alice.name).to eq("Alice")
    end
  end

  describe "#load" do
    it "documents that connection execute_batch is currently private" do
      connection = User.connection

      expect(connection.respond_to?(:execute_batch, true)).to be(true)
      expect(connection.private_methods).to include(:execute_batch)
      expect(connection.public_methods).not_to include(:execute_batch)
    end

    it "aggregates restore queries and executes one batch per connection" do
      user_sql = "INSERT INTO users (id, name) VALUES (1, 'Alice')"
      project_sql = "INSERT INTO projects (id, name, owner_id) VALUES (1, 'Website', 1)"
      activity_log_sql = "INSERT INTO activity_logs (id, action) VALUES (1, 'created')"
      allow(cache).to receive(:exists?).and_return(true)
      allow(FixtureKit::Repository).to receive(:new).with({}).and_return(:repository)
      cache.instance_variable_set(
        :@content,
        FixtureKit::MemoryCache.new(
          data: {
            FixtureKit::ActiveRecordCoder => {
              User => user_sql,
              Project => project_sql,
              ActivityLog => activity_log_sql
            }
          },
          exposed: {}
        )
      )

      primary_connection = User.connection
      analytics_connection = ActivityLog.connection
      primary_statements = [
        "DELETE FROM #{User.quoted_table_name}",
        user_sql,
        "DELETE FROM #{Project.quoted_table_name}",
        project_sql
      ]
      analytics_statements = [
        "DELETE FROM #{ActivityLog.quoted_table_name}",
        activity_log_sql
      ]

      expect(primary_connection).to receive(:disable_referential_integrity).once.and_yield
      expect(primary_connection).to receive(:execute_batch).with(primary_statements, "FixtureKit Insert").once
      expect(analytics_connection).to receive(:disable_referential_integrity).once.and_yield
      expect(analytics_connection).to receive(:execute_batch).with(analytics_statements, "FixtureKit Insert").once

      expect(cache.load).to eq(:repository)
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
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)

      fixture_cache.save

      User.delete_all
      repository = fixture_cache.load

      expect(repository.alice).to be_a(User)
      expect(repository.alice.name).to eq("Alice")
    end

  end

  describe "with a secondary coder" do
    let(:secondary_coder) do
      klass = Class.new(FixtureKit::Coder) do
        def generate(parent_data: nil, &block)
          yield
          { "key" => "value" }
        end

        def mount(data)
        end
      end
      stub_const("FixtureKit::SecondaryCoder", klass)
    end

    before do
      runner.configuration.register(secondary_coder)
    end

    it "saves secondary coder data to disk" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-cache@example.com")
        expose(alice: alice)
      end
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"].keys).to include("User")
      expect(data["data"]["FixtureKit::SecondaryCoder"]).to eq({ "key" => "value" })
    end

    it "loads secondary coder data from disk" do
      fixture_definition = FixtureKit::Definition.new {}
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save
      fixture_cache.clear_memory

      expect_any_instance_of(FixtureKit::SecondaryCoder).to receive(:mount).with({ "key" => "value" }).and_call_original
      fixture_cache.load
    end
  end

  describe "with a secondary coder that defines custom encode/decode" do
    let(:secondary_coder) do
      klass = Class.new(FixtureKit::Coder) do
        def generate(parent_data: nil, &block)
          yield if block_given?
          { "raw" => "value" }
        end

        def mount(data)
        end

        def encode(data)
          { "encoded" => true, "payload" => data }
        end

        def decode(data)
          data.fetch("payload")
        end
      end
      stub_const("FixtureKit::EncodingCoder", klass)
    end

    before do
      runner.configuration.register(secondary_coder)
    end

    it "writes encoded data to disk" do
      fixture_definition = FixtureKit::Definition.new do
        alice = User.create!(name: "Alice", email: "alice-cache@example.com")
        expose(alice: alice)
      end
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save

      data = JSON.parse(File.read(fixture_cache.path))
      expect(data["data"]["FixtureKit::ActiveRecordCoder"].keys).to include("User")
      expect(data["data"]["FixtureKit::EncodingCoder"]).to eq({ "encoded" => true, "payload" => { "raw" => "value" } })
    end

    it "passes decoded data to load after a round-trip through disk" do
      fixture_definition = FixtureKit::Definition.new {}
      fixture_double = instance_double(
        FixtureKit::Fixture,
        identifier: fixture_name,
        definition: fixture_definition,
        parent: nil
      )
      fixture_cache = described_class.new(fixture_double)
      fixture_cache.save
      fixture_cache.clear_memory

      expect_any_instance_of(FixtureKit::EncodingCoder).to receive(:mount).with({ "raw" => "value" }).and_call_original
      fixture_cache.load
    end
  end
end
