# frozen_string_literal: true

module FixtureKit
  module FixtureRegistry
    class << self
      def register(fixture)
        fixtures[fixture.name.to_s] = fixture
      end

      def find(name)
        fixtures[name.to_s]
      end

      def all_names
        fixtures.keys
      end

      # Load all fixture definition files from the given path.
      # Uses `load` instead of `require` to ensure fixtures are registered
      # even if the files were previously required (e.g., after a reset).
      def load_definitions(fixture_path)
        Dir.glob(File.join(fixture_path, "**/*.rb")).each do |file|
          load file
        end
      end

      def reset
        @fixtures = nil
      end

      # Load a fixture's records into the database and return a FixtureSet.
      # Uses cached INSERT statements if available, otherwise executes fixture and caches.
      def load_fixture(name)
        name = name.to_s

        # Load the file on-demand if fixture not yet registered
        unless find(name)
          fixture_path = FixtureKit.configuration.fixture_path
          file_path = File.expand_path(File.join(fixture_path, "#{name}.rb"))
          load file_path
        end

        runner = FixtureRunner.new(name)
        runner.run
      end

      private

      def fixtures
        @fixtures ||= {}
      end
    end
  end
end
