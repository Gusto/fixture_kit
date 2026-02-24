# frozen_string_literal: true

require "prism"
require "set"

module FixtureKit
  module Analyzer
    class AstFactoryDetector
      FACTORY_METHODS = %w[create build build_stubbed create_list build_list].to_set.freeze

      def initialize
        @file_cache = {}
      end

      # Returns array of factory name strings, e.g. ["company", "employee"]
      def detect(mod, method_name)
        meth = mod.instance_method(method_name)
        file, line = meth.source_location
        return [] unless file && File.exist?(file)

        ast = parse_file(file)
        block = find_block_at_line(ast, line)
        return [] unless block

        collect_factory_calls(block)
      rescue
        []
      end

      private

      def parse_file(path)
        @file_cache[path] ||= Prism.parse(File.read(path)).value
      end

      # Find the block node that starts at the target line.
      def find_block_at_line(node, target_line)
        if node.is_a?(Prism::BlockNode) && node.location.start_line == target_line
          return node
        end

        node.child_nodes.compact.each do |child|
          found = find_block_at_line(child, target_line)
          return found if found
        end

        nil
      end

      # Walk an AST subtree collecting factory call argument symbols.
      def collect_factory_calls(node)
        results = []

        if node.is_a?(Prism::CallNode) && FACTORY_METHODS.include?(node.name.to_s)
          first_arg = node.arguments&.arguments&.first
          results << first_arg.value if first_arg.is_a?(Prism::SymbolNode)
        end

        node.child_nodes.compact.each { |child| results.concat(collect_factory_calls(child)) }
        results
      end
    end
  end
end
