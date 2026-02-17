# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "factory_bot"
require "fileutils"
require "sqlite3"

ENV["RAILS_ENV"] = "test"

# Create tmp directory for test databases
FileUtils.mkdir_p("tmp")

# Clean up old test databases
FileUtils.rm_f("tmp/test.sqlite3")

# Connect to database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "tmp/test.sqlite3"
)

# Define models for database
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  has_many :orders
end

class Order < ApplicationRecord
  belongs_to :user
  has_many :line_items
end

class LineItem < ApplicationRecord
  belongs_to :order
end

class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Event < ApplicationRecord
end

# Create database schema
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.boolean :verified, default: false
    t.timestamps
  end

  create_table :orders, force: true do |t|
    t.references :user, foreign_key: true
    t.string :status
    t.decimal :total, precision: 10, scale: 2
    t.timestamps
  end

  create_table :line_items, force: true do |t|
    t.references :order, foreign_key: true
    t.string :product_name
    t.integer :quantity
    t.decimal :price, precision: 10, scale: 2
    t.timestamps
  end

  create_table :comments, force: true do |t|
    t.text :body
    t.references :commentable, polymorphic: true
    t.timestamps
  end

  create_table :events, force: true do |t|
    t.string :name
    t.text :data
    t.timestamps
  end
end

# Set up Factory Bot factories
FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    verified { false }

    trait :verified do
      verified { true }
    end

    trait :with_payment_method do
      # Placeholder trait for testing
    end
  end

  factory :order do
    user
    status { "pending" }
    total { 100.00 }
  end

  factory :line_item do
    order
    sequence(:product_name) { |n| "Product #{n}" }
    quantity { 1 }
    price { 25.00 }
  end

  factory :comment do
    body { "This is a comment" }
    association :commentable, factory: :user
  end

  factory :event do
    sequence(:name) { |n| "Event #{n}" }
    data { "{}" }
  end
end

require "fixtury_bot"
require "stringio"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.before(:each) do
    FixturyBot.reset
    FixturyBot.configuration.output = StringIO.new
    FactoryBot.rewind_sequences

    # Clean up test database (delete in order to respect foreign key constraints)
    LineItem.delete_all
    Comment.delete_all
    Order.delete_all
    User.delete_all
    Event.delete_all

    # Clean up generated fixture files
    fixtures_path = FixturyBot.configuration.fixtures_path
    FileUtils.rm_rf(fixtures_path) if Dir.exist?(fixtures_path)
  end

  config.after(:suite) do
    FileUtils.rm_f("tmp/test.sqlite3")
  end
end
