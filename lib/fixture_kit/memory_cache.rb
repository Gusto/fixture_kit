# frozen_string_literal: true

module FixtureKit
  class MemoryCache
    attr_reader :records, :exposed

    def initialize(records:, exposed:)
      @records = records
      @exposed = exposed
      freeze
    end

    def to_h
      { records: records, exposed: exposed }
    end
  end
end
