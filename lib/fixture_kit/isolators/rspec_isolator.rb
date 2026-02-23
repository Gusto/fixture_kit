# frozen_string_literal: true

module FixtureKit
  class RSpecIsolator < FixtureKit::Isolator
    def run(&block)
      previous_example = ::RSpec.current_example
      previous_scope = ::RSpec.current_scope
      example_group = build_example_group
      example = example_group.example { block.call }
      instance = example_group.new
      succeeded =
        begin
          example.run(instance, ::RSpec::Core::NullReporter)
        ensure
          ::RSpec.current_example = previous_example
          ::RSpec.current_scope = previous_scope
        end

      raise example.exception unless succeeded
    end

    private

    def build_example_group
      ::RSpec::Core::ExampleGroup.subclass(
        ::RSpec::Core::ExampleGroup,
        "FixtureKit",
        [],
        []
      )
    end
  end
end
