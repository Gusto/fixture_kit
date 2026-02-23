# frozen_string_literal: true

require "active_support/inflector"

module FixtureKit
  class RSpecAdapter < FixtureKit::Adapter
    def execute(&block)
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

    def identifier_for(identifier)
      normalized_scope = identifier.to_s.sub(/\ARSpec::ExampleGroups::/, "")
      ActiveSupport::Inflector.underscore(normalized_scope)
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
