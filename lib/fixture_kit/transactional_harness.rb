# frozen_string_literal: true

require "active_record/fixtures"

module FixtureKit
  # Runs arbitrary code inside ActiveRecord::TestFixtures lifecycle without
  # defining a real test example. This gives us Rails' transactional handling
  # across all configured writing pools.
  class TransactionalHarness
    include ActiveRecord::TestFixtures

    def self.run(&block)
      new.run(&block)
    end

    # ActiveRecord::TestFixtures checks `name` to decide whether the current
    # method is marked with `uses_transaction`.
    def name
      "fixture_kit_transactional_harness"
    end

    def run
      setup_fixtures
      yield
    ensure
      teardown_fixtures
    end
  end
end
