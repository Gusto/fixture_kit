# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "fileutils"
require "fixture_kit/minitest"

if Rails.env.production?
  abort("The Rails environment is running in production mode!")
end

module DummyFixtureKitTestSupport
  module_function

  def clear_fixture_cache
    FileUtils.rm_rf(FixtureKit.runner.configuration.cache_path)
  end

  def setup_databases
    ActiveRecord::Base.connection.disable_referential_integrity do
      ActiveRecord::Base.connection.drop_table(:comments, if_exists: true)
      ActiveRecord::Base.connection.drop_table(:tasks, if_exists: true)
      ActiveRecord::Base.connection.drop_table(:projects, if_exists: true)
      ActiveRecord::Base.connection.drop_table(:users, if_exists: true)
      ActiveRecord::Base.connection.drop_table(:vehicles, if_exists: true)
    end

    AnalyticsRecord.connection.disable_referential_integrity do
      AnalyticsRecord.connection.drop_table(:activity_logs, if_exists: true)
      AnalyticsRecord.connection.drop_table(:time_entries, if_exists: true)
    end

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

    ActiveRecord::Base.connection.create_table :vehicles, force: true do |t|
      t.string :type, null: false
      t.string :name, null: false
      t.integer :year
      t.timestamps
    end

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
end

FixtureKit.configure do |config|
  config.fixture_path = Rails.root.join("fixture_kit").to_s
end

DummyFixtureKitTestSupport.setup_databases
DummyFixtureKitTestSupport.clear_fixture_cache

Minitest.after_run do
  DummyFixtureKitTestSupport.clear_fixture_cache
end

class ActiveSupport::TestCase
  self.use_transactional_tests = true

  def custom_helper_method
    "helper.fixture@example.com"
  end
end
