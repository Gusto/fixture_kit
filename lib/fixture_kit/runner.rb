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

    def register(scope, name = nil, &definition_block)
      registry.add(scope, normalize_registration(name, definition_block))
    end

    def start
      raise RunnerAlreadyStartedError, "FixtureKit::Runner has already been started" if started?
      @started = true

      clear_cache unless preserve_cache?
    end

    def adapter
      @adapter ||= configuration.adapter.new(configuration.adapter_options)
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

    def normalize_registration(name, definition_block)
      if name && definition_block
        raise FixtureKit::InvalidFixtureDeclaration, "cannot provide both fixture name and definition block"
      end

      name_or_block = name || definition_block
      return name_or_block if name_or_block

      raise FixtureKit::InvalidFixtureDeclaration, "must provide fixture name or definition block"
    end
  end
end
