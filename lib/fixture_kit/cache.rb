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

      configuration.coders.map(&:new).each do |coder|
        coder.load(data.data_for(coder.class))
      end

      Repository.new(data.exposed)
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        @data = MemoryCache.new(
          data: evaluate(configuration.coders.map(&:new), context),
          exposed: file_cache.serialize_exposed(fixture.definition.exposed)
        )
      end

      file_cache.write(data)
    end

    private

    def evaluate(coders, context, memo = {}, &block)
      if coders.empty?
        fixture.definition.evaluate(context, parent: fixture.parent&.mount)
      else
        coder, *remaining_coders = coders

        parent_data = fixture.parent ? fixture.parent.cache.data.data_for(coder.class) : nil
        memo[coder.class] = coder.save(parent_data: parent_data) do
          evaluate(remaining_coders, context, memo, &block)
        end
      end

      memo
    end

    def file_cache
      @file_cache ||= FileCache.new(
        File.join(configuration.cache_path, "#{identifier}.json")
      )
    end
  end
end
