# frozen_string_literal: true

# Builds lightweight mock objects that mimic the RSpec example group tree
# structure the analyzer expects, without needing a real RSpec dry-run.
module AnalyzerHelpers
  # A minimal stand-in for an RSpec example (only needs to exist for counting)
  FakeExample = Struct.new(:description)

  # A minimal stand-in for an RSpec example group
  class FakeGroup
    attr_reader :examples, :children, :description, :metadata

    def initialize(description:, file_path: "unknown", examples: 0, lets: {}, children: [])
      @description = description
      @metadata = {file_path: file_path}
      @examples = Array.new(examples) { FakeExample.new("example") }
      @children = children
      @lets_module = build_lets_module(lets) if lets.any?
    end

    def const_get(name, inherit = true)
      raise NameError, "uninitialized constant #{name}" unless name == :LetDefinitions && @lets_module
      @lets_module
    end

    private

    # lets is a Hash of { method_name => { file:, line: } }
    # We define methods whose source_location points to the given file/line.
    def build_lets_module(lets)
      mod = Module.new
      lets.each do |method_name, loc|
        mod.module_eval(<<~RUBY, loc[:file], loc[:line])
          def #{method_name}; end
        RUBY
      end
      mod
    end
  end
end
