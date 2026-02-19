# frozen_string_literal: true

module FixtureKit
  class Fixture
    attr_reader :name, :block

    def initialize(name, &block)
      @name = name.to_sym
      @block = block
    end

    def execute
      context = FixtureContext.new
      context.instance_eval(&block) if block
      context.exposed
    end
  end

  class FixtureContext
    attr_reader :exposed

    def initialize
      @exposed = {}
    end

    def expose(**records)
      records.each do |name, record|
        name = name.to_sym

        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, <<~ERROR
            Duplicate expose name :#{name}

            A record with this name has already been exposed in this fixture.
          ERROR
        end

        @exposed[name] = record
      end
    end
  end
end
