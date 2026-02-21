# frozen_string_literal: true

require "fixture_kit"

module FixtureKit
  module RSpec
    autoload :Declaration, File.expand_path("rspec/declaration", __dir__)
    autoload :Generator, File.expand_path("rspec/generator", __dir__)

    DECLARATION_METADATA_KEY = :fixture_kit_declaration
    PRESERVE_CACHE_ENV_KEY = "FIXTURE_KIT_PRESERVE_CACHE"

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
        metadata[DECLARATION_METADATA_KEY] = Declaration.new(name)
      end
    end

    # Instance methods (included via config.include)
    module InstanceMethods
      # Returns the FixtureSet for the current example's fixture.
      # Access exposed records as methods: fixture.alice, fixture.posts
      def fixture
        @_fixture_kit_fixture_set || raise("No fixture declared for this example group. Use `fixture \"name\"` in your describe/context block.")
      end
    end

    def self.configure!(config)
      FixtureKit.configuration.generator = Generator
      config.extend ClassMethods
      config.include InstanceMethods

      # Load declared fixtures at the beginning of each example.
      # Runs inside transactional fixtures and before user-defined before hooks.
      config.prepend_before(:example, DECLARATION_METADATA_KEY) do |example|
        declaration = example.metadata[DECLARATION_METADATA_KEY]
        @_fixture_kit_fixture_set = declaration.fixture_set
      end

      # Setup caches at suite start only when at least one fixture-backed
      # example exists in the loaded suite.
      config.when_first_matching_example_defined(DECLARATION_METADATA_KEY) do
        config.before(:suite) do
          if FixtureKit.configuration.autogenerate
            preserve_cache = ENV[PRESERVE_CACHE_ENV_KEY].to_s.match?(/\A(1|true|yes)\z/i)
            FixtureCache.clear unless preserve_cache
          else
            FixtureCache.pregenerate_all
          end
        end
      end
    end
  end
end

# Configure RSpec integration
FixtureKit::RSpec.configure!(RSpec.configuration)
