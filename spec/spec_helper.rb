# frozen_string_literal: true

# Boot the dummy Rails app first
require_relative "support/dummy_rails_helper"

# Load rspec-rails for transactional fixtures support
require "rspec/rails"

# Load RSpec integration
require "fixtury_bot/rspec"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Include the FixturyBot RSpec DSL
  config.include FixturyBot::RSpec

  # Create database schema once at suite start
  config.before(:suite) do
    setup_databases
  end

  # Use transactional fixtures - each test runs in a transaction that rolls back
  config.use_transactional_fixtures = true

  # Reset FixturyBot configuration before each test
  config.before(:each) do
    FixturyBot.configuration.cache_path = Rails.root.join("tmp/fixtury_cache").to_s
    FixturyBot.configuration.fixtury_path = Rails.root.join("spec/fixtury").to_s
    FixturyBot.configuration.output = StringIO.new
  end

  # Clean up cache after suite
  config.after(:suite) do
    FixturyBot.clear_cache
  end
end
