# frozen_string_literal: true

# Boot the dummy Rails app for tests.

ENV["RAILS_ENV"] = "test"

require_relative "../dummy/config/environment"

require "fixture_kit"

# Helper to load fixtures in tests (wraps internal API)
def load_fixture(name)
  FixtureKit::FixtureRegistry.load_fixture(name)
end

# Helper to clear fixture cache in tests
def clear_fixture_cache(fixture_name = nil)
  FixtureKit::FixtureCache.clear(fixture_name)
end

# Create schema for both databases
def setup_databases
  # Primary database schema
  ActiveRecord::Base.connection.create_table :users, force: true do |t|
    t.string :name, null: false
    t.string :email, null: false
    t.string :role, default: "member"
    t.boolean :verified, default: false
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :projects, force: true do |t|
    t.string :name, null: false
    t.text :description
    t.string :status, default: "active"
    t.references :owner, null: false, foreign_key: { to_table: :users }
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :tasks, force: true do |t|
    t.string :title, null: false
    t.text :description
    t.string :status, default: "pending"
    t.date :due_date
    t.references :project, null: false, foreign_key: true
    t.references :assignee, null: false, foreign_key: { to_table: :users }
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :comments, force: true do |t|
    t.text :body, null: false
    t.references :commentable, polymorphic: true, null: false
    t.timestamps
  end

  # Analytics database schema
  AnalyticsRecord.connection.create_table :activity_logs, force: true do |t|
    t.integer :external_user_id, null: false
    t.string :action, null: false
    t.string :subject_type
    t.integer :subject_id
    t.json :metadata
    t.timestamps
  end

  AnalyticsRecord.connection.create_table :time_entries, force: true do |t|
    t.integer :external_user_id, null: false
    t.integer :external_task_id, null: false
    t.decimal :hours, precision: 5, scale: 2, null: false
    t.text :description
    t.datetime :logged_at, null: false
    t.timestamps
  end

  AnalyticsRecord.connection.add_index :activity_logs, :external_user_id
  AnalyticsRecord.connection.add_index :activity_logs, [:subject_type, :subject_id]
  AnalyticsRecord.connection.add_index :time_entries, :external_user_id
  AnalyticsRecord.connection.add_index :time_entries, :external_task_id
end

# Configure FixtureKit
FixtureKit.configure do |config|
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s
end
