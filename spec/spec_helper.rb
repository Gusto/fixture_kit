# frozen_string_literal: true

# Boot the dummy Rails app first
require_relative "support/dummy_rails_helper"

# Load rspec-rails for transactional fixtures support
require "rspec/rails"

# Load RSpec integration
require "fixture_kit/rspec"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Include the FixtureKit RSpec DSL
  config.include FixtureKit::RSpec

  # Create database schema once at suite start before FixtureKit startup hooks.
  config.prepend_before(:suite) do
    setup_databases
  end

  # Use transactional fixtures - each test runs in a transaction that rolls back
  config.use_transactional_fixtures = true

  # Keep fixture_kit configuration isolated per example.
  config.around(:each) do |example|
    configuration = FixtureKit.runner.configuration
    previous_cache_path = configuration.cache_path
    previous_fixture_path = configuration.fixture_path
    previous_isolator = configuration.isolator
    previous_on_cache = configuration.on_cache

    example.run
  ensure
    configuration.cache_path = previous_cache_path
    configuration.fixture_path = previous_fixture_path
    configuration.isolator = previous_isolator
    configuration.on_cache = previous_on_cache
  end

  # Clean up cache after suite
  config.after(:suite) do
    clear_fixture_cache
  end
end
