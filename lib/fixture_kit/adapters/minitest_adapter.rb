# frozen_string_literal: true

require "active_support/test_case"
require "active_record/fixtures"
require "active_support/inflector"

module FixtureKit
  class MinitestAdapter < FixtureKit::Adapter
    TEST_NAME = "fixture kit cache pregeneration"

    def execute(&block)
      test_class = build_test_class
      test_method = test_class.test(TEST_NAME) do
        block.call
        pass
      end

      result = test_class.new(test_method).run
      return if result.passed?

      raise result.failures.first.error
    end

    def identifier_for(identifier)
      File.join(Cache::ANONYMOUS_DIRECTORY, ActiveSupport::Inflector.underscore(identifier.to_s))
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
