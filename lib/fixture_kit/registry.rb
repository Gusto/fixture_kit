# frozen_string_literal: true

module FixtureKit
  module Registry
    class << self
      def fetch(name)
        fixture = find(name)
        return fixture if fixture

        file_path = fixture_file_path(name)
        unless File.file?(file_path)
          raise FixtureKit::FixtureDefinitionNotFound,
            "Could not find fixture definition file for '#{name}' at '#{file_path}'"
        end

        load file_path
        find(name)
      end

      def find(name)
        registry[name]
      end

      def fixtures
        registry.values
      end

      def register(fixture)
        registry[fixture.name] = fixture
      end

      # Load all fixture definition files.
      # Uses `load` instead of `require` to ensure fixtures are registered
      # even if the files were previously required (e.g., after a reset).
      def load_definitions
        fixture_path = FixtureKit.configuration.fixture_path
        Dir.glob(File.join(fixture_path, "**/*.rb")).each do |file|
          load file
        end
      end

      def reset
        @registry = nil
      end

      private

      def fixture_file_path(name)
        fixture_path = FixtureKit.configuration.fixture_path
        File.expand_path(File.join(fixture_path, "#{name}.rb"))
      end

      def registry
        @registry ||= {}
      end
    end
  end
end
