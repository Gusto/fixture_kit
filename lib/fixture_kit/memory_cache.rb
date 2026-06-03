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
      data.fetch(coder_class) do
        raise MissingCoderDataError,
          "The fixture cache has no data for #{coder_class}. This usually means " \
          "the cache was written before #{coder_class} was registered as a coder. " \
          "Regenerate the fixture cache so it includes this coder (clear the cache " \
          "directory, or run without FIXTURE_KIT_PRESERVE_CACHE=1)."
      end
    end
  end
end
