# frozen_string_literal: true

require "rails_helper"
require "json"
require "active_support/testing/time_helpers"

module FixtureKitIntegrationTimeHelpers
  include ActiveSupport::Testing::TimeHelpers
end

RSpec.configure do |config|
  config.include(FixtureKitIntegrationTimeHelpers)
end

# Shared examples auto-included via config.include_context to reproduce the
# ordering issue: RSpec creates the shared group during configuration (before
# the host group's `fixture` call sets metadata), so fixture declarations
# must propagate through runtime metadata inheritance.
RSpec.shared_examples "auto-included shared examples" do
  context "inside auto-included shared context" do
    let(:shared_user) { User.find_by!(email: "alice@team.test") }

    it "can access fixture data through let blocks defined in the host group" do
      expect(fixture.alice.email).to eq("alice@team.test")
      expect(shared_user).to eq(fixture.alice)
      puts "FKIT_ASSERT:SHARED_EXAMPLE_FIXTURE_ACCESS"
    end
  end
end

RSpec.configure do |config|
  config.include_context "auto-included shared examples", :include_shared_fixture_test
end

RSpec.describe "FixtureKit integration" do
  describe "fixture preload timing" do
    fixture "teams/basic"

    before do
      @user_count_in_before_hook = User.count
    end

    it "loads fixture data before before hooks run" do
      expect(@user_count_in_before_hook).to eq(2)
      puts "FKIT_ASSERT:FRAMEWORK:rspec"
      puts "FKIT_ASSERT:PRELOAD_BEFORE_HOOK"
    end
  end

  describe "fixture loading and exposure" do
    fixture "project_management"

    it "loads records into both databases" do
      expect(User.count).to eq(3)
      expect(Project.count).to eq(2)
      expect(Task.count).to eq(5)
      expect(Comment.count).to eq(2)
      expect(ActivityLog.count).to eq(2)
      expect(TimeEntry.count).to eq(3)
      puts "FKIT_ASSERT:MULTI_DB_COUNTS"
    end

    it "exposes records as methods" do
      expect(fixture.alice.name).to eq("Alice Chen")
      expect(fixture.web_app.name).to eq("Web App Redesign")
      expect(fixture.design_task.title).to eq("Design new homepage")
      puts "FKIT_ASSERT:EXPOSED_ACCESS"
    end

    it "exposes arrays" do
      expect(fixture.mobile_tasks).to be_an(Array)
      expect(fixture.mobile_tasks.size).to eq(3)
      expect(fixture.api_time_entries).to be_an(Array)
      expect(fixture.api_time_entries.size).to eq(2)
      puts "FKIT_ASSERT:ARRAY_EXPOSURE"
    end
  end

  describe "cache generation" do
    fixture "project_management"

    it "has pregenerated cache before example execution" do
      cache_file = File.join(FixtureKit.runner.configuration.cache_path, "project_management.json")
      expect(File.exist?(cache_file)).to be(true)
      puts "FKIT_ASSERT:CACHE_WRITTEN"
    end
  end

  describe "nested fixture paths" do
    fixture "teams/basic"

    it "loads nested fixture definitions" do
      expect(fixture.alice.name).to eq("Alice")
      expect(fixture.bob.name).to eq("Bob")
      puts "FKIT_ASSERT:NESTED_FIXTURE"
    end
  end

  describe "query event coverage" do
    fixture "query_type_events"

    it "captures all supported write event types for table dumping" do
      cache_file = File.join(FixtureKit.runner.configuration.cache_path, "query_type_events.json")
      cache_data = JSON.parse(File.read(cache_file))

      expect(cache_data.fetch("records").keys).to include("User", "Project", "Task", "Comment", "ActivityLog")
      puts "FKIT_ASSERT:QUERY_TYPES_CAPTURED"
    end
  end

  describe "transaction rollback" do
    fixture "project_management"

    it "creates a temporary row in first example" do
      expect(User.count).to eq(3)
      User.create!(name: "Temporary User", email: "temp@example.com")
      expect(User.count).to eq(4)
      puts "FKIT_ASSERT:ROLLBACK_FIRST_EXAMPLE"
    end

    it "does not persist previous example writes" do
      expect(User.count).to eq(3)
      puts "FKIT_ASSERT:ROLLBACK_SECOND_EXAMPLE"
    end
  end

  describe "anonymous fixture" do
    fixture do
      anonymous_user = User.create!(name: "Anonymous User", email: "anonymous.fixture@example.com")
      expose(anonymous_user: anonymous_user)
    end

    before do
      @anonymous_user_count_in_before_hook = User.count
    end

    it "loads and caches anonymous fixture data" do
      expect(@anonymous_user_count_in_before_hook).to eq(1)
      expect(fixture.anonymous_user.email).to eq("anonymous.fixture@example.com")

      normalized_scope = self.class.to_s.sub(/\ARSpec::ExampleGroups::/, "")
      cache_file = File.join(
        FixtureKit.runner.configuration.cache_path,
        "_anonymous/#{ActiveSupport::Inflector.underscore(normalized_scope)}.json"
      )
      expect(File.exist?(cache_file)).to be(true)

      puts "FKIT_ASSERT:ANONYMOUS_FIXTURE"
      puts "FKIT_ASSERT:ANONYMOUS_CACHE_PATH"
    end
  end

  describe "anonymous fixture overrides" do
    fixture "teams/basic"

    context "in nested groups" do
      fixture do
        override_user = User.create!(name: "Override User", email: "override.fixture@example.com")
        expose(override_user: override_user)
      end

      it "overrides parent fixture declaration" do
        expect(User.count).to eq(1)
        expect(fixture.override_user.email).to eq("override.fixture@example.com")
        puts "FKIT_ASSERT:ANONYMOUS_NESTED_OVERRIDE"
      end
    end
  end

  describe "anonymous fixture helper methods" do
    fixture do
      travel_to(Time.zone.parse("2024-03-02 10:15:00")) do
        user = User.create!(name: "Time Traveler", email: "time.fixture@example.com")
        expose(time_user: user)
      end
    end

    it "can call RSpec example helper methods during fixture generation" do
      expect(fixture.time_user.created_at).to eq(Time.zone.parse("2024-03-02 10:15:00"))
      puts "FKIT_ASSERT:ANONYMOUS_HELPER_METHODS"
    end
  end

  describe "fixture inheritance" do
    fixture "inheritance/grandchild"

    it "supports inheritance chains without auto-exposing parent records" do
      expect(User.count).to eq(1)
      expect(Project.count).to eq(1)
      expect(Task.count).to eq(1)
      expect(fixture.task.title).to eq("Inherited Task")
      expect(fixture.task.project.name).to eq("Inherited Project")
      expect(fixture.task.project.owner.email).to eq("inheritance.owner@example.com")
      expect { fixture.project }.to raise_error(NoMethodError)

      puts "FKIT_ASSERT:INHERITANCE_CHAIN"
    end
  end

  describe "inline fixture inheritance" do
    fixture(extends: "inheritance/base") do
      project = Project.create!(name: "Inline Inherited Project", owner: parent.owner)
      expose(project: project)
    end

    it "supports inline inheritance from named fixtures" do
      expect(User.count).to eq(1)
      expect(Project.count).to eq(1)
      expect(fixture.project.name).to eq("Inline Inherited Project")
      expect(fixture.project.owner.email).to eq("inheritance.owner@example.com")
      expect { fixture.owner }.to raise_error(NoMethodError)

      puts "FKIT_ASSERT:INLINE_INHERITANCE"
    end
  end

  describe "circular fixture inheritance" do
    it "raises a custom error for circular inheritance chains" do
      expect do
        FixtureKit.runner.register("inheritance/circular_a", Object.new)
      end.to raise_error(FixtureKit::CircularFixtureInheritance)

      puts "FKIT_ASSERT:CIRCULAR_INHERITANCE"
    end
  end

  describe "duplicate fixture declarations" do
    it "raises when declaring fixture twice in the same context" do
      expect do
        RSpec::Core::ExampleGroup.describe("Fixture duplicate declaration context") do
          fixture "teams/basic"
          fixture do
            user = User.create!(name: "Duplicate", email: "duplicate.fixture@example.com")
            expose(user: user)
          end
        end
      end.to raise_error(FixtureKit::MultipleFixtures, "cannot load multiple fixtures in the same context")

      puts "FKIT_ASSERT:ANONYMOUS_DUPLICATE_DECLARATION"
    end
  end

  describe "fixture with auto-included shared examples", :include_shared_fixture_test do
    fixture "teams/basic"

    it "works in the host group" do
      expect(fixture.alice.name).to eq("Alice")
      puts "FKIT_ASSERT:SHARED_EXAMPLE_HOST_FIXTURE"
    end
  end

  describe "fixture instance reader without declaration" do
    it "raises a helpful error message" do
      expect do
        fixture
      end.to raise_error(
        RuntimeError,
        "No fixture declared for this example group. Use `fixture \"name\"` in your describe/context block."
      )

      puts "FKIT_ASSERT:UNDECLARED_FIXTURE_READER"
    end
  end
end
