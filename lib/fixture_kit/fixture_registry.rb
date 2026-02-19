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
