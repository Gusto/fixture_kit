# frozen_string_literal: true

require "fixture_kit"

module FixtureKit
  module RSpec
    DECLARATION_METADATA_KEY = :fixture_kit_declaration

    # Class methods (extended via config.extend)
    module ClassMethods
      # Declare which fixture to use for this example group.
      # Can be overridden in nested groups (like `let`).
      #
      # Example:
      #   RSpec.describe User do
      #     fixture "basic_users"
      #
      #     it "has users" do
      #       expect(fixture.alice).to be_present
      #     end
      #
      #     context "with admins" do
      #       fixture "admin_users"  # Override
      #
      #       it "has admin" do
      #         expect(fixture.admin).to be_present
      #       end
      #     end
      #   end
      def fixture(name)
        if metadata[DECLARATION_METADATA_KEY]
          raise FixtureKit::MultipleFixtures, "cannot load multiple fixtures in the same example group"
        end

        metadata[DECLARATION_METADATA_KEY] = ::RSpec.configuration.fixture_kit.register(name)
      end
    end

    # Instance methods (included via config.include)
    module InstanceMethods
      # Returns the Repository for the current example's fixture.
      # Access exposed records as methods: fixture.alice, fixture.posts
      def fixture
        @_fixture_kit_repository || raise("No fixture declared for this example group. Use `fixture \"name\"` in your describe/context block.")
      end
    end

    def self.configure!(config)
      FixtureKit.runner.configuration.fixture_path = "spec/fixture_kit"
      config.add_setting(:fixture_kit, default: FixtureKit.runner)
      FixtureKit.runner.configuration.isolator = FixtureKit::RSpecIsolator

      config.extend ClassMethods
      config.include InstanceMethods, DECLARATION_METADATA_KEY

      # Load declared fixtures at the beginning of each example.
      # Runs inside transactional fixtures and before user-defined before hooks.
      config.prepend_before(:example, DECLARATION_METADATA_KEY) do |example|
        @_fixture_kit_repository = example.metadata[DECLARATION_METADATA_KEY].mount
      end

      config.append_before(:suite) do
        config.fixture_kit.start
      end
    end
  end
end

# Configure RSpec integration
FixtureKit::RSpec.configure!(RSpec.configuration)
