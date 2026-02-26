# frozen_string_literal: true

module FixtureKit
  module Analyzer
    class FileResult
      attr_reader :file, :total_examples, :lets

      def initialize(file:, total_examples:, lets:)
        @file = file
        @total_examples = total_examples
        @lets = lets.sort_by { |l| -l.example_count }
      end

      def max_reuse
        lets.first&.example_count || 0
      end

      def to_h
        {
          file: file,
          total_examples: total_examples,
          max_reuse: max_reuse,
          lets: lets.map(&:to_h),
        }
      end
    end
  end
end
