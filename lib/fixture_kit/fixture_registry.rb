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

      private

      def fixtures
        @fixtures ||= {}
      end
    end
  end
end
