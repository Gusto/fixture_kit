# frozen_string_literal: true

require "json"

module FixtureKit
  module Analyzer
    class Runner
      def initialize(
        format: ENV.fetch("ANALYZER_FORMAT", "text"),
        limit: ENV.fetch("ANALYZER_LIMIT", "50").to_i,
        lets_per_file: ENV.fetch("ANALYZER_LETS_PER_FILE", "8").to_i,
        min_reuse: ENV.fetch("ANALYZER_MIN_REUSE", "2").to_i,
        output_path: ENV["ANALYZER_OUTPUT"]
      )
        @format = format
        @limit = limit
        @lets_per_file = lets_per_file
        @min_reuse = min_reuse
        @output_path = output_path
      end

      def run(example_groups)
        return if example_groups.empty?

        total = example_groups.length
        $stderr.puts "[fixture_kit:analyzer] Analyzing #{total} top-level example groups..."

        analyzer = GroupAnalyzer.new

        by_file = Hash.new { |h, k| h[k] = {lets: [], total_examples: 0} }

        example_groups.each_with_index do |group, idx|
          file = group.metadata[:file_path] || group.metadata[:absolute_file_path] || "unknown"
          if (idx + 1) % 500 == 0 || idx + 1 == total
            $stderr.puts "[fixture_kit:analyzer] Processing group #{idx + 1}/#{total} (#{file})"
          end
          by_file[file][:total_examples] += analyzer.total_examples(group)
          analyzer.analyze(group, by_file[file][:lets])
        end

        results = by_file.map do |file, data|
          FileResult.new(file: file, total_examples: data[:total_examples], lets: data[:lets])
        end.sort_by { |r| -r.max_reuse }

        output(results)
        results
      end

      # Install the at_exit hook that runs the analyzer after rspec --dry-run
      def self.install_rspec_hook!
        load_start = Time.now

        progress_thread = Thread.new do
          last_count = 0
          loop do
            sleep 5
            current = ::RSpec.world.example_groups.length rescue 0
            if current != last_count
              $stderr.puts "[fixture_kit:analyzer] Loading... #{current} top-level groups found (#{(Time.now - load_start).round(1)}s)"
              last_count = current
            end
          end
        end
        progress_thread.abort_on_exception = false

        at_exit do
          progress_thread.kill
          next unless defined?(::RSpec) && ::RSpec.world.example_groups.any?

          $stderr.puts "[fixture_kit:analyzer] Spec loading complete: #{::RSpec.world.example_groups.length} groups in #{(Time.now - load_start).round(1)}s"
          new.run(::RSpec.world.example_groups)
        end
      end

      private

      def output(results)
        case @format
        when "json"
          json = JSON.pretty_generate(results.map(&:to_h))
          $stdout.puts json
        else
          TextFormatter.new(
            limit: @limit,
            lets_per_file: @lets_per_file,
            min_reuse: @min_reuse,
          ).render(results)
        end

        if @output_path
          File.write(@output_path, JSON.pretty_generate(results.map(&:to_h)))
          $stderr.puts "[fixture_kit:analyzer] Full JSON written to: #{@output_path}"
        end
      end
    end
  end
end
