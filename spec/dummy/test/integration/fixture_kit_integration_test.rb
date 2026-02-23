# frozen_string_literal: true

require "test_helper"

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
