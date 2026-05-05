# frozen_string_literal: true

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"

    include ConfigurationHelper

    attr_reader :fixture, :data

    def initialize(fixture)
      @fixture = fixture
    end

    def path
      file_cache.path
    end

    def identifier
      @identifier ||= begin
        raw_identifier = fixture.identifier
        if raw_identifier.is_a?(String)
          raw_identifier
        else
          File.join(ANONYMOUS_DIRECTORY, FixtureKit.runner.adapter.identifier_for(raw_identifier))
        end
      end
    end

    def exists?
      data || file_cache.exists?
    end

    def clear_memory
      @data = nil
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      @data ||= file_cache.read
      coder.mount(data.data_for(ActiveRecordCoder))

      Repository.new(data.exposed)
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        coder.observe do
          fixture.definition.evaluate(context, parent: fixture.parent&.mount)
        end

        @data = MemoryCache.new(
          data: { ActiveRecordCoder => coder.save(parent_data: fixture.parent ? fixture.parent.cache.data_for(ActiveRecordCoder) : nil) },
          exposed: file_cache.serialize_exposed(fixture.definition.exposed)
        )
      end

      file_cache.write(data)
    end

    private

    def coder
      @coder ||= ActiveRecordCoder.new
    end

    def file_cache
      @file_cache ||= FileCache.new(
        File.join(configuration.cache_path, "#{identifier}.json")
      )
    end
  end
end
