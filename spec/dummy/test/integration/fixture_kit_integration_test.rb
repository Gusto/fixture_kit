# frozen_string_literal: true

require "test_helper"
require "json"

class FixtureKitProjectManagementIntegrationTest < ActiveSupport::TestCase
  fixture "project_management"

  setup do
    @user_count_in_setup = User.count
  end

  test "loads fixture data before setup hooks run" do
    assert_equal 3, @user_count_in_setup
    puts "FKIT_ASSERT:FRAMEWORK:minitest"
    puts "FKIT_ASSERT:PRELOAD_BEFORE_HOOK"
  end

  test "loads records into both databases" do
    assert_equal 3, User.count
    assert_equal 2, Project.count
    assert_equal 5, Task.count
    assert_equal 2, Comment.count
    assert_equal 2, ActivityLog.count
    assert_equal 3, TimeEntry.count
    puts "FKIT_ASSERT:MULTI_DB_COUNTS"
  end

  test "exposes records as methods" do
    assert_equal "Alice Chen", fixture.alice.name
    assert_equal "Web App Redesign", fixture.web_app.name
    assert_equal "Design new homepage", fixture.design_task.title
    puts "FKIT_ASSERT:EXPOSED_ACCESS"
  end

  test "exposes arrays" do
    assert_kind_of Array, fixture.mobile_tasks
    assert_equal 3, fixture.mobile_tasks.size
    assert_kind_of Array, fixture.api_time_entries
    assert_equal 2, fixture.api_time_entries.size
    puts "FKIT_ASSERT:ARRAY_EXPOSURE"
  end

  test "has pregenerated cache before test execution" do
    cache_file = File.join(FixtureKit.runner.configuration.cache_path, "project_management.json")
    assert File.exist?(cache_file)
    puts "FKIT_ASSERT:CACHE_WRITTEN"
  end

  test "creates a temporary row in first test" do
    assert_equal 3, User.count
    User.create!(name: "Temporary User", email: "temp@example.com")
    assert_equal 4, User.count
    puts "FKIT_ASSERT:ROLLBACK_FIRST_EXAMPLE"
  end

  test "does not persist writes from other tests" do
    assert_equal 3, User.count
    puts "FKIT_ASSERT:ROLLBACK_SECOND_EXAMPLE"
  end
end

class FixtureKitNestedFixtureIntegrationTest < ActiveSupport::TestCase
  fixture "teams/basic"

  test "loads nested fixture definitions" do
    assert_equal "Alice", fixture.alice.name
    assert_equal "Bob", fixture.bob.name
    puts "FKIT_ASSERT:NESTED_FIXTURE"
  end
end

class FixtureKitQueryEventCoverageIntegrationTest < ActiveSupport::TestCase
  fixture "query_type_events"

  test "captures all supported write event types for table dumping" do
    cache_file = File.join(FixtureKit.runner.configuration.cache_path, "query_type_events.json")
    cache_data = JSON.parse(File.read(cache_file))

    assert_includes cache_data.fetch("data").fetch("FixtureKit::ActiveRecordCoder").keys, "User"
    assert_includes cache_data.fetch("data").fetch("FixtureKit::ActiveRecordCoder").keys, "Project"
    assert_includes cache_data.fetch("data").fetch("FixtureKit::ActiveRecordCoder").keys, "Task"
    assert_includes cache_data.fetch("data").fetch("FixtureKit::ActiveRecordCoder").keys, "Comment"
    assert_includes cache_data.fetch("data").fetch("FixtureKit::ActiveRecordCoder").keys, "ActivityLog"
    puts "FKIT_ASSERT:QUERY_TYPES_CAPTURED"
  end
end

class FixtureKitAnonymousFixtureIntegrationTest < ActiveSupport::TestCase
  fixture do
    anonymous_user = User.create!(name: "Anonymous User", email: "anonymous.fixture@example.com")
    expose(anonymous_user: anonymous_user)
  end

  setup do
    @anonymous_user_count_in_setup = User.count
  end

  test "loads and caches anonymous fixture data" do
    assert_equal 1, @anonymous_user_count_in_setup
    assert_equal "anonymous.fixture@example.com", fixture.anonymous_user.email

    cache_file = File.join(
      FixtureKit.runner.configuration.cache_path,
      "_anonymous/#{ActiveSupport::Inflector.underscore(self.class.name)}.json"
    )
    assert File.exist?(cache_file)

    puts "FKIT_ASSERT:ANONYMOUS_FIXTURE"
    puts "FKIT_ASSERT:ANONYMOUS_CACHE_PATH"
  end
end

class FixtureKitAnonymousHelperMethodsIntegrationTest < ActiveSupport::TestCase
  fixture do
    helper_user = User.create!(name: "Helper User", email: custom_helper_method)
    expose(helper_user: helper_user)
  end

  test "can call ActiveSupport::TestCase helper methods during fixture generation" do
    assert_equal "helper.fixture@example.com", fixture.helper_user.email
    puts "FKIT_ASSERT:ANONYMOUS_HELPER_METHODS"
  end
end

class FixtureKitInheritanceIntegrationTest < ActiveSupport::TestCase
  fixture "inheritance/grandchild"

  test "supports inheritance chains without auto-exposing parent records" do
    assert_equal 1, User.count
    assert_equal 1, Project.count
    assert_equal 1, Task.count
    assert_equal "Inherited Task", fixture.task.title
    assert_equal "Inherited Project", fixture.task.project.name
    assert_equal "inheritance.owner@example.com", fixture.task.project.owner.email
    assert_raises(NoMethodError) { fixture.project }

    puts "FKIT_ASSERT:INHERITANCE_CHAIN"
  end
end

class FixtureKitInlineInheritanceIntegrationTest < ActiveSupport::TestCase
  fixture(extends: "inheritance/base") do
    project = Project.create!(name: "Inline Inherited Project", owner: parent.owner)
    expose(project: project)
  end

  test "supports inline inheritance from named fixtures" do
    assert_equal 1, User.count
    assert_equal 1, Project.count
    assert_equal "Inline Inherited Project", fixture.project.name
    assert_equal "inheritance.owner@example.com", fixture.project.owner.email
    assert_raises(NoMethodError) { fixture.owner }

    puts "FKIT_ASSERT:INLINE_INHERITANCE"
  end
end

class FixtureKitCircularInheritanceIntegrationTest < ActiveSupport::TestCase
  test "raises a custom error for circular inheritance chains" do
    assert_raises(FixtureKit::CircularFixtureInheritance) do
      FixtureKit.runner.register("inheritance/circular_a", Object.new)
    end

    puts "FKIT_ASSERT:CIRCULAR_INHERITANCE"
  end
end

class FixtureKitAnonymousParentFixtureIntegrationTest < ActiveSupport::TestCase
  fixture "teams/basic"
end

class FixtureKitAnonymousOverrideIntegrationTest < FixtureKitAnonymousParentFixtureIntegrationTest
  fixture do
    override_user = User.create!(name: "Override User", email: "override.fixture@example.com")
    expose(override_user: override_user)
  end

  test "overrides parent fixture declaration" do
    assert_equal 1, User.count
    assert_equal "override.fixture@example.com", fixture.override_user.email
    puts "FKIT_ASSERT:ANONYMOUS_NESTED_OVERRIDE"
  end
end

class FixtureKitAnonymousDuplicateDeclarationIntegrationTest < ActiveSupport::TestCase
  test "raises when declaring fixture twice in the same context" do
    error = assert_raises(FixtureKit::MultipleFixtures) do
      Class.new(ActiveSupport::TestCase) do
        fixture "teams/basic"
        fixture do
          user = User.create!(name: "Duplicate", email: "duplicate.fixture@example.com")
          expose(user: user)
        end
      end
    end

    assert_equal "cannot load multiple fixtures in the same context", error.message
    puts "FKIT_ASSERT:ANONYMOUS_DUPLICATE_DECLARATION"
  end
end

class FixtureKitUnscopedRecordLookupIntegrationTest < ActiveSupport::TestCase
  fixture "soft_deleted_project"

  test "finds exposed records even when hidden by default_scope" do
    assert_equal 1, Project.count
    assert_equal 2, Project.unscoped.count

    assert_equal "Archived Project", fixture.archived_project.name
    assert_not_nil fixture.archived_project.deleted_at
    assert_equal "Active Project", fixture.active_project.name
    puts "FKIT_ASSERT:UNSCOPED_RECORD_LOOKUP"
  end
end

class FixtureKitUndeclaredFixtureReaderIntegrationTest < ActiveSupport::TestCase
  test "raises a helpful error message when fixture is called without declaration" do
    error = assert_raises(RuntimeError) { fixture }

    assert_equal(
      "No fixture declared for this test class. Use `fixture \"name\"` in your test class.",
      error.message
    )
    puts "FKIT_ASSERT:UNDECLARED_FIXTURE_READER"
  end
end
