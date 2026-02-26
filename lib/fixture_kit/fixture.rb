# frozen_string_literal: true

require "benchmark"

module FixtureKit
  class Fixture
    include ConfigurationHelper

    attr_reader :identifier, :definition, :parent, :cache

    def initialize(identifier, definition)
      @identifier = identifier
      @definition = definition
      @cache = Cache.new(self)

      if definition.extends
        @parent = FixtureKit.runner.registry.add(definition.extends)
      end
    end

    def generate(force: false)
      return if @cache.exists? && !force

      parent&.generate

      emit(:cache_save)
      emit(:cache_saved) { @cache.save }
    end

    def mount
      unless @cache.exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{identifier}'"
      end

      emit(:cache_mount)
      emit(:cache_mounted) { @cache.load }
    end

    private

    def emit(event)
      cache_identifier = @cache.identifier
      unless block_given?
        configuration.callbacks.run(event, cache_identifier)
        return
      end

      value = nil
      elapsed = Benchmark.realtime do
        value = yield
      end
      configuration.callbacks.run(event, cache_identifier, elapsed)
      value
    end
  end
end
