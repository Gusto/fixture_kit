# frozen_string_literal: true

require "fixture_kit"
require "active_support/lazy_load_hooks"

module FixtureKit
  module Minitest
    DECLARATION_CLASS_ATTRIBUTE = :fixture_kit_declaration

    module ClassMethods
      def fixture(name)
        self.fixture_kit_declaration = FixtureKit.runner.register(name)
      end
    end

    module InstanceMethods
      def fixture
        @_fixture_kit_repository || raise("No fixture declared for this test class. Use `fixture \"name\"` in your test class.")
      end
    end

    def self.configure!(test_case)
      FixtureKit.runner.configuration.isolator = FixtureKit::MinitestIsolator

      test_case.class_attribute DECLARATION_CLASS_ATTRIBUTE, instance_accessor: false
      test_case.extend ClassMethods
      test_case.include InstanceMethods

      test_case.setup do
        declaration = self.class.fixture_kit_declaration
        next unless declaration

        FixtureKit.runner.start unless FixtureKit.runner.started?
        @_fixture_kit_repository = declaration.mount
      end
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  FixtureKit::Minitest.configure!(self)
end
