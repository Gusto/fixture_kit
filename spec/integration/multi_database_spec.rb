# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-database integration" do
  describe "fixture loading with RSpec DSL" do
    fixtury :project_management

    it "loads fixtures into correct databases" do
      # Accessing fixtury triggers the load
      fixtury

      # Primary database records
      expect(User.count).to eq(3)
      expect(Project.count).to eq(2)
      expect(Task.count).to eq(5)  # 2 individual + 3 from create_list
      expect(Comment.count).to eq(2)

      # Analytics database records
      expect(ActivityLog.count).to eq(2)
      expect(TimeEntry.count).to eq(3)
    end

    it "exposes records via fixtury accessor" do
      expect(fixtury.alice).to be_a(User)
      expect(fixtury.alice.name).to eq("Alice Chen")
      expect(fixtury.alice.role).to eq("admin")

      expect(fixtury.web_app).to be_a(Project)
      expect(fixtury.web_app.name).to eq("Web App Redesign")

      expect(fixtury.design_task).to be_a(Task)
      expect(fixtury.design_task.title).to eq("Design new homepage")
    end

    it "loads arrays from create_list" do
      expect(fixtury.mobile_tasks).to be_an(Array)
      expect(fixtury.mobile_tasks.size).to eq(3)
      expect(fixtury.mobile_tasks).to all(be_a(Task))

      expect(fixtury.api_time_entries).to be_an(Array)
      expect(fixtury.api_time_entries.size).to eq(2)
      expect(fixtury.api_time_entries).to all(be_a(TimeEntry))
    end

    it "supports hash-style access" do
      expect(fixtury[:alice]).to be_a(User)
      expect(fixtury[:web_app]).to be_a(Project)
    end
  end

  describe "soft foreign key preservation" do
    fixtury :project_management

    it "stores external IDs in fixtures" do
      design_time = fixtury.design_time
      api_time_entries = fixtury.api_time_entries

      expect(design_time.external_user_id).to be_a(Integer)
      expect(design_time.external_task_id).to be_a(Integer)
      expect(api_time_entries.first.external_user_id).to be_a(Integer)
      expect(api_time_entries.first.external_task_id).to be_a(Integer)
    end

    it "stores consistent external IDs across fixtures" do
      api_time_entries = fixtury.api_time_entries

      # Both time entries for Bob's API task should have the same external_task_id
      task_ids = api_time_entries.map(&:external_task_id).uniq
      expect(task_ids.size).to eq(1)

      # Both should have the same external_user_id (Bob's)
      user_ids = api_time_entries.map(&:external_user_id).uniq
      expect(user_ids.size).to eq(1)
    end
  end

  describe "database isolation" do
    fixtury :project_management

    it "uses correct database connections for each model" do
      fixtury  # Trigger load

      expect(User.connection.pool.db_config.name).to eq("primary")
      expect(Project.connection.pool.db_config.name).to eq("primary")
      expect(Task.connection.pool.db_config.name).to eq("primary")

      expect(ActivityLog.connection.pool.db_config.name).to eq("analytics")
      expect(TimeEntry.connection.pool.db_config.name).to eq("analytics")
    end
  end

  describe "transaction rollback" do
    fixtury :project_management

    it "rolls back data after each test (first test)" do
      fixtury
      expect(User.count).to eq(3)
      # Data will be rolled back after this test
    end

    it "rolls back data after each test (second test)" do
      # Database should be empty at start (previous test's data rolled back)
      expect(User.count).to eq(0)

      # Load fixtury for this test
      fixtury
      expect(User.count).to eq(3)
    end
  end

  describe "caching" do
    it "creates cache file on first run" do
      FixturyBot.clear_cache(:project_management)

      cache_file = File.join(FixturyBot.configuration.cache_path, "project_management.yml")
      expect(File.exist?(cache_file)).to be(false)

      # Load fixtury (creates cache)
      FixturyBot.load_fixtury(:project_management)

      expect(File.exist?(cache_file)).to be(true)

      # Verify cache content structure
      cache_data = YAML.unsafe_load_file(cache_file)
      expect(cache_data["records"]).to be_a(Hash)
      expect(cache_data["records"].keys).to include("User")
      expect(cache_data["exposed"]).to be_a(Hash)
    end

    it "uses cache when loading in a new transaction (first test creates cache)" do
      # This test and the next test together verify caching works across tests
      # This test creates the cache
      FixturyBot.load_fixtury(:project_management)
      expect(User.count).to eq(3)
    end

    it "uses cache when loading in a new transaction (second test uses cache)" do
      # Cache should exist from previous test
      cache_file = File.join(FixturyBot.configuration.cache_path, "project_management.yml")
      expect(File.exist?(cache_file)).to be(true)

      # Load fixtury - should use cache (replay INSERTs)
      fixture_set = FixturyBot.load_fixtury(:project_management)

      # Verify records were loaded from cache
      expect(User.count).to eq(3)
      expect(fixture_set.alice).to be_a(User)
    end
  end
end
