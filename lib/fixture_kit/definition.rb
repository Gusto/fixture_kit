# frozen_string_literal: true

module FixtureKit
  class Definition
    attr_reader :exposed, :source_location

    def initialize(&definition)
      @definition = definition
      @source_location = definition.source_location
      @exposed = {}
    end

    def evaluate(context)
      context.singleton_class.prepend(mixin)
      context.instance_exec(&@definition)
    end

    def expose(**records)
      records.each do |name, record|
        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, "Name #{name} already exposed"
        end

        @exposed[name] = record
      end
    end

    private

    def mixin
      definition = self

      Module.new do
        define_method(:expose) do |**records|
          definition.expose(**records)
        end
      end
    end
  end
end
