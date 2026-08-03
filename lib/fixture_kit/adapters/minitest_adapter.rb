# frozen_string_literal: true

require "active_support/test_case"
require "active_record/fixtures"
require "active_support/inflector"

module FixtureKit
  class MinitestAdapter < FixtureKit::Adapter
    TEST_NAME = "fixture kit cache pregeneration"
    TEST_METHOD = :"test_#{TEST_NAME.tr(" ", "_")}"

    def execute(&block)
      test = test_class.new(TEST_METHOD)
      # Minitest runs a test by sending its name to the instance, so defining it
      # here leaves the reused class untouched and the block dies with the test.
      test.define_singleton_method(TEST_METHOD) do
        block.call(self)
        pass
      end

      result = test.run
      return if result.passed?

      raise result.failures.first.error
    end

    def identifier_for(identifier)
      ActiveSupport::Inflector.underscore(identifier.to_s)
    end

    private

    # Reused rather than built per generation: including
    # ActiveRecord::TestFixtures appends the class to ActiveSupport's
    # :active_record_fixtures load hooks, and that never shrinks.
    def test_class
      @test_class ||= Class.new(ActiveSupport::TestCase) do
        ::Minitest::Runnable.runnables.delete(self)
        include(::ActiveRecord::TestFixtures)
      end
    end
  end
end
