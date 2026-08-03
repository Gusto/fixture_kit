# frozen_string_literal: true

require "active_support/inflector"

module FixtureKit
  class RSpecAdapter < FixtureKit::Adapter
    def execute(&block)
      previous_example = ::RSpec.current_example
      previous_scope = ::RSpec.current_scope
      group = example_group
      example = group.example { block.call(self) }
      succeeded =
        begin
          example.run(group.new, ::RSpec::Core::NullReporter)
        ensure
          # The group is reused, and the example it holds retains this block.
          group.examples.clear
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

    # Reused rather than built per generation: rspec-rails includes
    # ActiveRecord::TestFixtures into every group, which appends it to
    # ActiveSupport's :active_record_fixtures load hooks, and that never shrinks.
    def example_group
      @example_group ||= ::RSpec::Core::ExampleGroup.subclass(
        ::RSpec::Core::ExampleGroup,
        "FixtureKit",
        [],
        []
      )
    end
  end
end
