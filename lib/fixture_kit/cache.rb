# frozen_string_literal: true

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"

    include ConfigurationHelper

    attr_reader :fixture, :content

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
      content || file_cache.exists?
    end

    def clear_memory
      @content = nil
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      read_content

      FixtureKit.runner.coders.each do |coder|
        coder.mount(content.data_for(coder.class))
      end

      Repository.new(content.exposed)
    end

    # Lazily loads @content from the file cache. Used when content is needed in
    # memory without a full mount (e.g. when a child fixture is being saved and
    # needs the parent's coder data, while the parent itself was already cached
    # to disk in a previous process and has not yet been mounted).
    def read_content
      @content ||= file_cache.read
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        @content = MemoryCache.new(
          data: evaluate(FixtureKit.runner.coders, context),
          exposed: file_cache.serialize_exposed(fixture.definition.exposed)
        )
      end

      file_cache.write(content)
    end

    private

    def evaluate(coders, context, data = {}, &block)
      if coders.empty?
        fixture.definition.evaluate(context, parent: fixture.parent&.mount)
      else
        coder, *remaining_coders = coders

        parent_data = fixture.parent&.cache&.read_content&.data_for(coder.class)
        data[coder.class] = coder.generate(parent_data: parent_data) do
          evaluate(remaining_coders, context, data, &block)
        end
      end

      data
    end

    def file_cache
      @file_cache ||= FileCache.new(
        File.join(configuration.cache_path, "#{identifier}.json")
      )
    end
  end
end
