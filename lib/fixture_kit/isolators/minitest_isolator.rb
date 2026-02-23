# frozen_string_literal: true

require "active_support/test_case"
require "active_record/fixtures"

module FixtureKit
  class MinitestIsolator < FixtureKit::Isolator
    TEST_NAME = "fixture kit cache pregeneration"

    def run(&block)
      test_class = build_test_class
      test_method = test_class.test(TEST_NAME) do
        block.call
        pass
      end

      result = test_class.new(test_method).run
      return if result.passed?

      raise result.failures.first.error
    end

    private

    def build_test_class
      Class.new(ActiveSupport::TestCase) do
        ::Minitest::Runnable.runnables.delete(self)
        include(::ActiveRecord::TestFixtures)
      end
    end
  end
end
