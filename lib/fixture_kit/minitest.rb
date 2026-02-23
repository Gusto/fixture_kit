# frozen_string_literal: true

require "fixture_kit"
require "active_support/lazy_load_hooks"

module FixtureKit
  module Minitest
    DECLARATION_CLASS_ATTRIBUTE = :fixture_kit_declaration

    module ClassMethods
      def fixture(name = nil, &definition_block)
        self.fixture_kit_declaration = FixtureKit.runner.register(self, name, &definition_block)
      end

      def run_suite(reporter, options = {})
        declaration = fixture_kit_declaration
        if declaration && !filter_runnable_methods(options).empty?
          runner = FixtureKit.runner
          runner.start unless runner.started?
          declaration.cache
        end

        super
      end
    end

    module InstanceMethods
      def fixture
        @_fixture_kit_repository || raise("No fixture declared for this test class. Use `fixture \"name\"` in your test class.")
      end
    end

    def self.configure!(test_case)
      FixtureKit.runner.configuration.fixture_path = "test/fixture_kit"
      FixtureKit.runner.configuration.adapter(FixtureKit::MinitestAdapter)

      test_case.class_attribute DECLARATION_CLASS_ATTRIBUTE, instance_accessor: false
      test_case.extend ClassMethods
      test_case.include InstanceMethods

      test_case.setup do
        declaration = self.class.fixture_kit_declaration
        next unless declaration

        @_fixture_kit_repository = declaration.mount
      end
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  FixtureKit::Minitest.configure!(self)
end
