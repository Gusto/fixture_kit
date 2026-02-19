# frozen_string_literal: true

module FixtureKit
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
