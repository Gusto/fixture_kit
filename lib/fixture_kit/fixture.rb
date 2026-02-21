# frozen_string_literal: true

module FixtureKit
  class Fixture
    attr_reader :name, :block

    def initialize(name, &block)
      @name = name
      @block = block
    end

    def execute
      context = DefinitionContext.new
      context.instance_eval(&block) if block
      context.exposed
    end
  end
end
