# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-database integration" do
  describe "fixture preload timing" do
    fixture "teams/basic"

    before do
      @user_count_in_before_hook = User.count
    end

    it "loads fixture data before before hooks run" do
      expect(@user_count_in_before_hook).to eq(2)
    end
  end

  describe "fixture loading with RSpec DSL" do
    fixture "project_management"

    it "loads fixtures into correct databases" do
      # Accessing fixture triggers the load
      fixture

      # Primary database records
      expect(User.count).to eq(3)
      expect(Project.count).to eq(2)
      expect(Task.count).to eq(5)  # 2 individual + 3 from create_list
      expect(Comment.count).to eq(2)

      # Analytics database records
      expect(ActivityLog.count).to eq(2)
      expect(TimeEntry.count).to eq(3)
    end

    it "exposes records via fixture accessor" do
      expect(fixture.alice).to be_a(User)
      expect(fixture.alice.name).to eq("Alice Chen")
      expect(fixture.alice.role).to eq("admin")

      expect(fixture.web_app).to be_a(Project)
      expect(fixture.web_app.name).to eq("Web App Redesign")

      expect(fixture.design_task).to be_a(Task)
      expect(fixture.design_task.title).to eq("Design new homepage")
    end

    it "loads arrays from create_list" do
      expect(fixture.mobile_tasks).to be_an(Array)
      expect(fixture.mobile_tasks.size).to eq(3)
      expect(fixture.mobile_tasks).to all(be_a(Task))

      expect(fixture.api_time_entries).to be_an(Array)
      expect(fixture.api_time_entries.size).to eq(2)
      expect(fixture.api_time_entries).to all(be_a(TimeEntry))
    end
  end

  describe "soft foreign key preservation" do
    fixture "project_management"

    it "stores external IDs in fixtures" do
      design_time = fixture.design_time
      api_time_entries = fixture.api_time_entries

      expect(design_time.external_user_id).to be_a(Integer)
      expect(design_time.external_task_id).to be_a(Integer)
      expect(api_time_entries.first.external_user_id).to be_a(Integer)
      expect(api_time_entries.first.external_task_id).to be_a(Integer)
    end

    it "stores consistent external IDs across fixtures" do
      api_time_entries = fixture.api_time_entries

      # Both time entries for Bob's API task should have the same external_task_id
      task_ids = api_time_entries.map(&:external_task_id).uniq
      expect(task_ids.size).to eq(1)

      # Both should have the same external_user_id (Bob's)
      user_ids = api_time_entries.map(&:external_user_id).uniq
      expect(user_ids.size).to eq(1)
    end
  end

  describe "database isolation" do
    fixture "project_management"

    it "uses correct database connections for each model" do
      fixture  # Trigger load

      expect(User.connection.pool.db_config.name).to eq("primary")
      expect(Project.connection.pool.db_config.name).to eq("primary")
      expect(Task.connection.pool.db_config.name).to eq("primary")

      expect(ActivityLog.connection.pool.db_config.name).to eq("analytics")
      expect(TimeEntry.connection.pool.db_config.name).to eq("analytics")
    end
  end

  describe "transaction rollback" do
    fixture "project_management"

    it "rolls back data after each test (first test)" do
      expect(User.count).to eq(3)
      User.create!(name: "Temporary User", email: "temp@example.com")
      expect(User.count).to eq(4)
      # Temporary user will be rolled back after this test
    end

    it "rolls back data after each test (second test)" do
      # Previous test's extra row is rolled back, then fixture is preloaded for this test
      expect(User.count).to eq(3)
    end
  end

  describe "caching" do
    it "loads fixture data on first run after clearing cache file" do
      clear_fixture_cache("project_management")

      cache_file = File.join(FixtureKit.configuration.cache_path, "project_management.json")
      expect(File.exist?(cache_file)).to be(false)

      fixture_set = load_fixture("project_management")

      expect(User.count).to eq(3)
      expect(fixture_set.alice).to be_a(User)
    end

    it "uses cache when loading in a new transaction (first test creates cache)" do
      # This test and the next test together verify caching works across tests
      # This test creates the cache
      load_fixture("project_management")
      expect(User.count).to eq(3)
    end

    it "uses cache when loading in a new transaction (second test uses cache)" do
      # Load fixture - should use cache (replay INSERTs)
      fixture_set = load_fixture("project_management")

      # Verify records were loaded from cache
      expect(User.count).to eq(3)
      expect(fixture_set.alice).to be_a(User)
    end
  end

  describe "nested fixture paths" do
    fixture "teams/basic"

    it "loads fixture from nested path" do
      expect(fixture.alice).to be_a(User)
      expect(fixture.alice.name).to eq("Alice")
      expect(fixture.bob).to be_a(User)
      expect(fixture.bob.name).to eq("Bob")
    end

    it "loads nested fixture after clearing its cache file" do
      clear_fixture_cache("teams/basic")

      cache_file = File.join(FixtureKit.configuration.cache_path, "teams/basic.json")
      expect(File.exist?(cache_file)).to be(false)

      fixture_set = load_fixture("teams/basic")

      expect(fixture_set.alice.name).to eq("Alice")
      expect(fixture_set.bob.name).to eq("Bob")
    end
  end

  describe "cache invalidation" do
    it "clear_fixture_cache removes cache file and fixture still loads" do
      load_fixture("project_management")

      cache_file = File.join(FixtureKit.configuration.cache_path, "project_management.json")

      clear_fixture_cache("project_management")

      expect(File.exist?(cache_file)).to be(false)
      expect { load_fixture("project_management") }.not_to raise_error
      expect(User.count).to eq(3)
    end
  end

end
