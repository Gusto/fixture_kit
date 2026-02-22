# frozen_string_literal: true

require "rails_helper"

module FixtureDeclaration
  def fixture_declaration(name)
    if INTEGRATION_FRAMEWORK == "rspec"
      fixture(name)
      return
    end

    declared_fixture = FixtureKit.runner.register(name)

    let(:fixture) do
      @_fixture_kit_fixture_set || raise("No fixture declared for this example group.")
    end

    prepend_before(:example) do
      @_fixture_kit_fixture_set = declared_fixture.mount
    end
  end
end

RSpec.configure do |config|
  config.extend FixtureDeclaration
end

RSpec.describe "FixtureKit integration" do
  describe "fixture preload timing" do
    fixture_declaration "teams/basic"

    before do
      @user_count_in_before_hook = User.count
    end

    it "loads fixture data before before hooks run" do
      expect(@user_count_in_before_hook).to eq(2)
      puts "FKIT_ASSERT:FRAMEWORK:#{INTEGRATION_FRAMEWORK}"
      puts "FKIT_ASSERT:PRELOAD_BEFORE_HOOK"
    end
  end

  describe "fixture loading and exposure" do
    fixture_declaration "project_management"

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
    fixture_declaration "project_management"

    it "has pregenerated cache before example execution" do
      cache_file = File.join(FixtureKit.runner.configuration.cache_path, "project_management.json")
      expect(File.exist?(cache_file)).to be(true)
      puts "FKIT_ASSERT:CACHE_WRITTEN"
    end
  end

  describe "nested fixture paths" do
    fixture_declaration "teams/basic"

    it "loads nested fixture definitions" do
      expect(fixture.alice.name).to eq("Alice")
      expect(fixture.bob.name).to eq("Bob")
      puts "FKIT_ASSERT:NESTED_FIXTURE"
    end
  end

  describe "transaction rollback" do
    fixture_declaration "project_management"

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
end
