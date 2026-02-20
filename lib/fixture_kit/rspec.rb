# frozen_string_literal: true

require "fixture_kit"
require_relative "rspec/declaration"
require_relative "rspec/generator"

module FixtureKit
  module RSpec
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
        metadata[FixtureKit::RSpec::DECLARATION_METADATA_KEY] = FixtureKit::RSpec::Declaration.new(name)
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
  end
end

# Install the RSpec generator by default for this entrypoint.
FixtureKit.configuration.generator = FixtureKit::RSpec::Generator

# Configure RSpec integration
RSpec.configure do |config|
  config.extend FixtureKit::RSpec::ClassMethods
  config.include FixtureKit::RSpec::InstanceMethods

  # Load declared fixtures at the beginning of each example.
  # Runs inside transactional fixtures and before user-defined before hooks.
  config.prepend_before(:example, FixtureKit::RSpec::DECLARATION_METADATA_KEY) do |example|
    declaration = example.metadata[FixtureKit::RSpec::DECLARATION_METADATA_KEY]
    @_fixture_kit_fixture_set = declaration.fixture_set
  end

  # Setup caches at suite start based on autogenerate setting
  # - autogenerate=true: Clear all caches (unless FIXTURE_KIT_PRESERVE_CACHE is set)
  # - autogenerate=false: Pre-generate all caches so tests don't fail
  config.before(:suite) do
    if FixtureKit.configuration.autogenerate
      preserve_cache = ENV[FixtureKit::RSpec::PRESERVE_CACHE_ENV_KEY].to_s.match?(/\A(1|true|yes)\z/i)
      FixtureKit::FixtureCache.clear unless preserve_cache
    else
      FixtureKit::FixtureCache.pregenerate_all
    end
  end
end
