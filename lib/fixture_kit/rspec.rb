# frozen_string_literal: true

require "fixture_kit"

module FixtureKit
  module RSpec
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
        metadata[:fixture_name] = name.to_s
      end
    end

    # Instance methods (included via config.include)
    module InstanceMethods
      # Returns the FixtureSet for the current example's fixture.
      # Access exposed records as methods: fixture.alice, fixture.posts
      def fixture
        @_fixture_loaded ||= begin
          fixture_name = self.class.metadata[:fixture_name]
          raise "No fixture declared for this example group. Use `fixture \"name\"` in your describe/context block." unless fixture_name

          FixtureKit::FixtureRegistry.load_fixture(fixture_name)
        end
      end
    end
  end
end

# Configure RSpec integration
RSpec.configure do |config|
  config.extend FixtureKit::RSpec::ClassMethods
  config.include FixtureKit::RSpec::InstanceMethods

  # Setup caches at suite start based on autogenerate setting
  # - autogenerate=true: Clear all caches (unless FIXTURE_KIT_PRESERVE_CACHE is set)
  # - autogenerate=false: Pre-generate all caches so tests don't fail
  config.before(:suite) do
    if FixtureKit.configuration.autogenerate
      preserve_cache = ENV["FIXTURE_KIT_PRESERVE_CACHE"].to_s.match?(/\A(1|true|yes)\z/i)
      FixtureKit::FixtureCache.clear unless preserve_cache
    else
      FixtureKit::FixtureCache.pregenerate_all
    end
  end
end
