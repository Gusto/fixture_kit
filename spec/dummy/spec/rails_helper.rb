# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "fileutils"
require "rspec/rails"

INTEGRATION_FRAMEWORK = ENV.fetch("FIXTURE_KIT_INTEGRATION_FRAMEWORK", "rspec")

case INTEGRATION_FRAMEWORK
when "rspec"
  require "fixture_kit/rspec"
when "minitest"
  require "fixture_kit"
else
  raise ArgumentError, "Unsupported integration framework: #{INTEGRATION_FRAMEWORK}"
end

if Rails.env.production?
  abort("The Rails environment is running in production mode!")
end

def clear_fixture_cache
  FileUtils.rm_rf(FixtureKit.runner.configuration.cache_path)
end

def setup_databases
  ActiveRecord::Base.connection.disable_referential_integrity do
    ActiveRecord::Base.connection.drop_table(:comments, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:tasks, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:projects, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:users, if_exists: true)
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

FixtureKit.configure do |config|
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.prepend_before(:suite) do
    setup_databases
    clear_fixture_cache

    if INTEGRATION_FRAMEWORK == "minitest"
      FixtureKit.runner.start
    end
  end

  config.after(:suite) do
    clear_fixture_cache
  end
end
