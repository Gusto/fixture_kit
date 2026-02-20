# frozen_string_literal: true

module FixtureKit
  module RSpec
    class Generator < FixtureKit::Generator
      def run(&block)
        previous_example = ::RSpec.current_example
        previous_scope = ::RSpec.current_scope
        example_group = build_example_group
        example = build_example(example_group, &block)
        instance = example_group.new(example.inspect_output)
        succeeded =
          begin
            example.run(instance, ::RSpec::Core::NullReporter)
          ensure
            example_group.remove_example(example)
            ::RSpec.current_example = previous_example
            ::RSpec.current_scope = previous_scope
          end

        unless succeeded
          raise example.exception if example.exception
          raise FixtureKit::PregenerationError, "FixtureKit pregeneration failed"
        end
      end

      private

      def build_example(example_group, &block)
        example_group.example(
          "FixtureKit cache pregeneration"
        ) { block.call }
      end

      def build_example_group
        ::RSpec::Core::ExampleGroup.subclass(
          ::RSpec::Core::ExampleGroup,
          "FixtureKit::RSpec::Generator",
          [],
          []
        )
      end
    end
  end
end
