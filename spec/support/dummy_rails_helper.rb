# frozen_string_literal: true

# Boot the dummy Rails app for tests.
require "fileutils"

ENV["RAILS_ENV"] = "test"

require_relative "../dummy/config/environment"

require "fixture_kit"

# Helper to load fixtures in tests (wraps internal API)
def load_fixture(name)
  FixtureKit.runner.register(Object.new, name).mount
end

# Helper to clear fixture cache in tests
def clear_fixture_cache(fixture_name = nil)
  cache_path = FixtureKit.runner.configuration.cache_path

  if fixture_name
    FileUtils.rm_f(File.join(cache_path, "#{fixture_name}.json"))
  else
    FileUtils.rm_rf(cache_path)
  end
end

class TestDatabaseBootstrap < ActiveRecord::Base
  self.abstract_class = true
end

# Ensure non-sqlite test databases exist before connecting (sqlite files auto-create).
# Uses a separate connection class so the main ActiveRecord::Base connection
# is established cleanly later from its own configuration.
def ensure_test_databases_exist!
  return if ENV.fetch("FIXTURE_KIT_DB", "sqlite3") == "sqlite3"

  ActiveRecord::Base.configurations.configs_for(env_name: "test").each do |db_config|
    create_database_if_missing(db_config)
  end
end

def create_database_if_missing(db_config)
  config = db_config.configuration_hash.dup
  database = config[:database]

  case config[:adapter]
  when "postgresql"
    config = config.merge(database: "postgres")
  when "mysql2"
    config = config.except(:database)
  else
    return
  end

  bootstrap = TestDatabaseBootstrap
  bootstrap.remove_connection if bootstrap.connected?
  bootstrap.establish_connection(config)
  quoted = bootstrap.connection.quote_column_name(database)

  case db_config.adapter
  when "postgresql"
    bootstrap.connection.execute("CREATE DATABASE #{quoted}")
  when "mysql2"
    bootstrap.connection.execute("CREATE DATABASE IF NOT EXISTS #{quoted}")
  end
rescue ActiveRecord::StatementInvalid => e
  raise unless e.message.include?("already exists")
ensure
  TestDatabaseBootstrap.remove_connection if TestDatabaseBootstrap.connected?
end

# Create schema for both databases
def setup_databases
  ensure_test_databases_exist!

  ActiveRecord::Base.connection.disable_referential_integrity do
    ActiveRecord::Base.connection.drop_table(:comments, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:tasks, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:projects, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:users, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:vehicles, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:gadgets, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:computed_widgets, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:binary_blob_children, if_exists: true, force: :cascade)
    ActiveRecord::Base.connection.drop_table(:binary_blobs, if_exists: true, force: :cascade)
  end

  AnalyticsRecord.connection.disable_referential_integrity do
    AnalyticsRecord.connection.drop_table(:activity_logs, if_exists: true, force: :cascade)
    AnalyticsRecord.connection.drop_table(:time_entries, if_exists: true, force: :cascade)
  end

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
    t.datetime :deleted_at
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

  ActiveRecord::Base.connection.create_table :vehicles, force: true do |t|
    t.string :type, null: false
    t.string :name, null: false
    t.integer :year
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :gadgets, force: true do |t|
    t.string :type, null: false
    t.string :name, null: false
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :computed_widgets, force: true do |t|
    t.string :name, null: false
    t.integer :quantity, null: false, default: 0
    t.virtual :name_upper, type: :string, as: "UPPER(name)", stored: true
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :binary_blobs, force: true do |t|
    t.binary :payload, limit: 16, null: false
    t.string :label, null: false
    t.json :metadata
    t.text :secret_note
    t.timestamps
  end

  ActiveRecord::Base.connection.create_table :binary_blob_children, force: true do |t|
    t.binary :payload, limit: 16, null: false
    t.references :binary_blob, null: false, foreign_key: true
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
  config.fixture_path = Rails.root.join("fixture_kit").to_s
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s
  config.adapter(FixtureKit::RSpecAdapter) if defined?(FixtureKit::RSpecAdapter)
end
