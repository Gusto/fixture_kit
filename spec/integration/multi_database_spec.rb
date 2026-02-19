# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-database integration" do
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

    it "supports hash-style access" do
      expect(fixture[:alice]).to be_a(User)
      expect(fixture[:web_app]).to be_a(Project)
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
      fixture
      expect(User.count).to eq(3)
      # Data will be rolled back after this test
    end

    it "rolls back data after each test (second test)" do
      # Database should be empty at start (previous test's data rolled back)
      expect(User.count).to eq(0)

      # Load fixture for this test
      fixture
      expect(User.count).to eq(3)
    end
  end

  describe "caching" do
    it "creates cache file on first run" do
      clear_fixture_cache("project_management")

      cache_file = File.join(FixtureKit.configuration.cache_path, "project_management.json")
      expect(File.exist?(cache_file)).to be(false)

      # Load fixture (creates cache)
      load_fixture("project_management")

      expect(File.exist?(cache_file)).to be(true)

      # Verify cache content structure
      cache_data = JSON.parse(File.read(cache_file))
      expect(cache_data["records"]).to be_a(Hash)
      expect(cache_data["records"].keys).to include("User")
      expect(cache_data["records"]["User"]).to be_a(String)
      expect(cache_data["records"]["User"]).to match(/INSERT OR IGNORE INTO/i)
      expect(cache_data["exposed"]).to be_a(Hash)
    end

    it "uses cache when loading in a new transaction (first test creates cache)" do
      # This test and the next test together verify caching works across tests
      # This test creates the cache
      load_fixture("project_management")
      expect(User.count).to eq(3)
    end

    it "uses cache when loading in a new transaction (second test uses cache)" do
      # Cache should exist from previous test
      cache_file = File.join(FixtureKit.configuration.cache_path, "project_management.json")
      expect(File.exist?(cache_file)).to be(true)

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

    it "creates cache in nested directory" do
      clear_fixture_cache("teams/basic")

      cache_file = File.join(FixtureKit.configuration.cache_path, "teams/basic.json")
      expect(File.exist?(cache_file)).to be(false)

      load_fixture("teams/basic")

      expect(File.exist?(cache_file)).to be(true)
    end
  end

  describe "memory caching" do
    it "caches parsed JSON in memory (first load populates cache)" do
      # Clear both memory and disk cache
      clear_fixture_cache("project_management")
      expect(FixtureKit::FixtureCache.memory_cache.key?("project_management")).to be(false)

      # First load - should populate memory cache
      load_fixture("project_management")

      expect(FixtureKit::FixtureCache.memory_cache.key?("project_management")).to be(true)
      expect(User.count).to eq(3)
    end

    it "uses memory cache on subsequent loads (second load uses memory)" do
      # Memory cache should exist from previous test
      expect(FixtureKit::FixtureCache.memory_cache.key?("project_management")).to be(true)

      # Delete disk cache to prove memory cache is used
      cache_file = File.join(FixtureKit.configuration.cache_path, "project_management.json")
      FileUtils.rm_f(cache_file)
      expect(File.exist?(cache_file)).to be(false)

      # Load should still work using memory cache
      fixture_set = load_fixture("project_management")

      expect(User.count).to eq(3)
      expect(fixture_set.alice).to be_a(User)
    end

    it "clear_cache removes from memory" do
      # Ensure memory cache has entry
      FixtureKit::FixtureCache.memory_cache["test_memory"] = { "records" => {} }

      clear_fixture_cache("test_memory")

      expect(FixtureKit::FixtureCache.memory_cache.key?("test_memory")).to be(false)
    end
  end

end
