# frozen_string_literal: true

module FixtureKit
  module RSpec
    class Declaration
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def fixture_set
        FixtureKit::Runner.run(name)
      end
    end
  end
end
