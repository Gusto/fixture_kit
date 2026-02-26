# frozen_string_literal: true

module FixtureKit
  module Analyzer
    class TextFormatter
      def initialize(limit:, lets_per_file:, min_reuse:, io: $stdout)
        @limit = limit
        @lets_per_file = lets_per_file
        @min_reuse = min_reuse
        @io = io
      end

      def render(results)
        filtered = results.select { |r| r.max_reuse >= @min_reuse }

        @io.puts
        @io.puts "=" * 110
        @io.puts "FACTORY LET REUSE (ranked by highest single-let example count)"
        @io.puts "=" * 110
        @io.puts
        @io.puts "#{results.length} spec files analyzed, #{filtered.length} with max reuse >= #{@min_reuse}"

        filtered.first(@limit).each_with_index do |result, idx|
          @io.puts
          @io.puts "#{idx + 1}. #{result.file}"
          @io.puts "   examples: #{result.total_examples}  |  factory lets: #{result.lets.length}  |  max reuse: #{result.max_reuse}"
          @io.puts "   " + "-" * 95

          result.lets.first(@lets_per_file).each do |l|
            @io.puts Kernel.format("   let(:%s)  examples: %d  factories: %s",
              l.name, l.example_count, l.factories.join(", "))
            @io.puts "      group: #{l.group_description}"
          end

          remaining = result.lets.length - @lets_per_file
          @io.puts "   ... +#{remaining} more" if remaining > 0
        end

        @io.puts
      end
    end
  end
end
