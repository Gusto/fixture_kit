# frozen_string_literal: true

module FixtureKit
  module Analyzer
    class LetDefinition
      attr_reader :name, :factories, :example_count, :file, :line, :group_description

      def initialize(name:, factories:, example_count:, file:, line:, group_description:)
        @name = name
        @factories = factories
        @example_count = example_count
        @file = file
        @line = line
        @group_description = group_description
      end

      def defined_at
        "#{file}:#{line}"
      end

      def to_h
        {
          let_name: name,
          factories: factories,
          example_count: example_count,
          defined_at: defined_at,
          group: group_description,
        }
      end
    end
  end
end
