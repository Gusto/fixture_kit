# frozen_string_literal: true

module FixtureKit
  module Analyzer
    class GroupAnalyzer
      def initialize(detector: AstFactoryDetector.new)
        @detector = detector
      end

      # Check if a group directly defines a let with this name
      def group_defines_let?(group, let_name)
        own_mod = group.const_get(:LetDefinitions, false)
        own_mod.instance_methods(false).include?(let_name.to_sym)
      rescue NameError
        false
      end

      # Count examples that inherit a let defined at `group`, stopping at overrides
      def examples_using_let(group, let_name)
        count = group.examples.count
        group.children.each do |child|
          next if group_defines_let?(child, let_name)
          count += examples_using_let(child, let_name)
        end
        count
      end

      # Total examples in group + all descendants
      def total_examples(group)
        group.examples.count + group.children.sum { |c| total_examples(c) }
      end

      # Walk tree, collect factory lets
      def analyze(group, results = [])
        own_mod = begin
          group.const_get(:LetDefinitions, false)
        rescue NameError
          nil
        end

        if own_mod
          own_mod.instance_methods(false).each do |method_name|
            factories = @detector.detect(own_mod, method_name)
            next if factories.empty?

            loc = own_mod.instance_method(method_name).source_location
            example_count = examples_using_let(group, method_name.to_s)

            results << LetDefinition.new(
              name: method_name.to_s,
              factories: factories,
              example_count: example_count,
              file: loc&.first,
              line: loc&.last,
              group_description: group.description.to_s[0, 80],
            )
          end
        end

        group.children.each { |child| analyze(child, results) }
        results
      end
    end
  end
end
