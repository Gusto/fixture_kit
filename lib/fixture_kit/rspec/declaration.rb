# frozen_string_literal: true

module FixtureKit
  module RSpec
    class Declaration
      attr_reader :name

      def initialize(name)
        @name = name.to_s
      end

      def fixture_set
        FixtureKit::FixtureRunner.run(name)
      end
    end
  end
end
