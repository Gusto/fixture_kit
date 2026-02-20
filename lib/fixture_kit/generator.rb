# frozen_string_literal: true

require "active_record/fixtures"

module FixtureKit
  # Base generator used to generate fixture caches.
  # By default this only wraps execution in ActiveRecord::TestFixtures.
  class Generator
    include ActiveRecord::TestFixtures

    def self.run(&block)
      new.run(&block)
    end

    # ActiveRecord::TestFixtures checks `name` to decide whether the current
    # method is marked with `uses_transaction`.
    def name
      "fixture_kit_generator"
    end

    def run
      setup_fixtures
      yield
    ensure
      teardown_fixtures
    end
  end
end
