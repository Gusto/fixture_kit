# frozen_string_literal: true

require "fileutils"

module FixtureKit
  class Runner
    PRESERVE_CACHE_ENV_KEY = "FIXTURE_KIT_PRESERVE_CACHE"

    attr_reader :configuration, :registry

    def initialize
      @configuration = Configuration.new
      @registry = Registry.new
      @adapter = nil
      @started = false
    end

    def register(name_or_definition, scope)
      fixture = registry.add(name_or_definition, scope)
      configuration.callbacks.run(:register, Event.new(fixture), scope)
      fixture
    end

    def start
      raise RunnerAlreadyStartedError, "FixtureKit::Runner has already been started" if started?
      @started = true

      clear_cache unless preserve_cache?
    end

    def adapter
      @adapter ||= configuration.adapter.new(configuration.adapter_options)
    end

    def coders
      @coders ||= configuration.coders.map(&:new)
    end

    def started?
      @started
    end

    private

    def clear_cache
      FileUtils.rm_rf(configuration.cache_path)
    end

    def preserve_cache?
      ENV[PRESERVE_CACHE_ENV_KEY].to_s.match?(/\A(1|true|yes)\z/i)
    end
  end
end
