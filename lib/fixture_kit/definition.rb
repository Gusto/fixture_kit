# frozen_string_literal: true

module FixtureKit
  class Definition
    attr_reader :exposed

    def initialize(&definition)
      @definition = definition
      @exposed = {}
    end

    def evaluate
      instance_eval(&@definition)
    end

    def expose(**records)
      records.each do |name, record|
        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, "Name #{name} already exposed"
        end

        @exposed[name] = record
      end
    end
  end
end
