# frozen_string_literal: true

module FixtureKit
  class Event
    attr_reader :fixture

    def initialize(fixture)
      @fixture = fixture
    end

    def identifier
      fixture.cache.identifier
    end

    def path
      fixture.definition.source_location
    end
  end
end
