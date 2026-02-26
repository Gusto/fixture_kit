# frozen_string_literal: true

module FixtureKit
  class Definition
    attr_reader :exposed, :extends

    def initialize(extends: nil, &definition)
      @definition = definition
      @exposed = {}
      @extends = extends
    end

    def evaluate(context, parent: nil)
      context.singleton_class.prepend(mixin(parent))
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

    def mixin(parent)
      definition = self

      Module.new do
        define_method(:expose) do |**records|
          definition.expose(**records)
        end

        define_method(:parent) do
          parent
        end
      end
    end
  end
end
