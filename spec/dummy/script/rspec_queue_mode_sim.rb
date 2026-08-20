# frozen_string_literal: true

require_relative "../spec/rails_helper"

spec_path = File.expand_path("../spec", __dir__)
$LOAD_PATH.unshift(spec_path) unless $LOAD_PATH.include?(spec_path)

module QueueModeSimulation
  module_function

  BATCHES = [
    ["spec/integration/queue_mode/batch_one.rb"],
    ["spec/integration/queue_mode/batch_two_late.rb"],
    ["spec/integration/queue_mode/batch_three_collision.rb"],
    ["spec/integration/queue_mode/batch_four_collision.rb"]
  ]

  def run
    ordering_strategy = RSpec.configuration.ordering_registry.fetch(:global)
    all_batches_passed = true

    RSpec.configuration.reporter.report(0) do |reporter|
      RSpec.configuration.with_suite_hooks do
        BATCHES.each_with_index do |batch_files, index|
          RSpec.world.reset

          batch_files.each do |relative_path|
            load(File.expand_path("../#{relative_path}", __dir__))
          end

          if index.zero?
            late_cache_path = File.join(FixtureKit.runner.configuration.cache_path, "queue_mode/late_subset.json")
            if File.exist?(late_cache_path)
              raise "Expected late fixture cache to be absent after running batch one"
            end

            puts "FKIT_ASSERT:QMODE_LATE_CACHE_ABSENT_AFTER_BATCH1"
          end

          batch_example_groups = ordering_strategy.order(RSpec.world.example_groups)
          batch_passed = batch_example_groups.map { |group| group.run(reporter) }.all?
          all_batches_passed &&= batch_passed
        end
      end
    end

    puts "FKIT_ASSERT:QMODE_COMPLETE" if all_batches_passed
    exit(all_batches_passed ? 0 : 1)
  rescue StandardError => e
    warn "Queue mode simulation failed: #{e.class}: #{e.message}"
    warn e.backtrace.join("\n")
    exit(1)
  end
end

QueueModeSimulation.run
