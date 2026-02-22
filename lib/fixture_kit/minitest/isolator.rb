# frozen_string_literal: true

require "active_support/test_case"
require "active_record/fixtures"

module FixtureKit
  module Minitest
    class Isolator < FixtureKit::Isolator
      TEST_METHOD_NAME = "test_fixture_kit_cache_pregeneration"

      def run(&block)
        result = build_test_class(&block).run
        return if result.passed?

        failure = result.failures.first
        raise failure.error if failure.respond_to?(:error)
        raise failure if failure

        raise FixtureKit::PregenerationError, "FixtureKit pregeneration failed"
      end

      private

      def build_test_class(&block)
        Class.new(ActiveSupport::TestCase) do
          ::Minitest::Runnable.runnables.delete(self)
          include(::ActiveRecord::TestFixtures)

          define_method(TEST_METHOD_NAME) do
            block.call
            pass
          end
        end.new(TEST_METHOD_NAME)
      end
    end
  end
end
