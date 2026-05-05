# frozen_string_literal: true

module FixtureKit
  class MemoryCache
    attr_reader :data, :exposed

    def initialize(data:, exposed:)
      @data = data
      @exposed = exposed
      freeze
    end

    def data_for(coder_class)
      data.fetch(coder_class)
    end

    def to_h
      { data: data, exposed: exposed }
    end
  end
end
