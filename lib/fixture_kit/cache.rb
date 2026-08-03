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

      @content ||= file_cache.read

      FixtureKit.runner.coders.each do |coder|
        coder.mount(content.data_for(coder.class))
      end

      Repository.new(content.exposed)
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        @content = MemoryCache.new(
          data: evaluate(FixtureKit.runner.coders, context),
          exposed: fixture.definition.exposed
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

        parent_data = fixture.parent ? fixture.parent.cache.content.data_for(coder.class) : nil
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
