# frozen_string_literal: true

require "pathname"

module FixtureKit
  module Singleton
    def configure
      @configuration = Configuration.new
      yield(@configuration) if block_given?
      self
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def define(&block)
      caller_file = File.expand_path(caller_locations(1, 1).first.path)
      fixture_path = File.expand_path(configuration.fixture_path)

      # "/abs/path/spec/fixtures/teams/basic.rb" -> "teams/basic"
      relative_path = Pathname.new(caller_file).relative_path_from(Pathname.new(fixture_path))
      name = relative_path.to_s.sub(/\.rb$/, "")

      fixture = Fixture.new(name, &block)
      FixtureRegistry.register(fixture)
      fixture
    end

    # Load a fixture's records into the database and return a FixtureSet.
    # Uses cached INSERT statements if available, otherwise executes fixture and caches.
    def load_fixture(name)
      name = name.to_s
      definition_file = File.join(configuration.fixture_path, "#{name}.rb")

      # Require the file on-demand if fixture not yet registered
      unless FixtureRegistry.find(name)
        require definition_file
      end

      runner = FixtureRunner.new(
        name,
        cache_path: configuration.cache_path,
        definition_file: definition_file,
        model_registry: @model_registry
      )
      runner.run
    end

    # Set a model registry for table -> model class mapping
    # Useful when models can't be inferred from table names
    def model_registry=(registry)
      @model_registry = registry
    end

    def model_registry
      @model_registry
    end

    # Clear the fixture cache for a specific fixture or all
    def clear_cache(fixture_name = nil)
      # Clear in-memory cache
      FixtureCache.clear_memory_cache(fixture_name)

      # Clear disk cache
      if fixture_name
        cache_file = File.join(configuration.cache_path, "#{fixture_name}.json")
        FileUtils.rm_f(cache_file)
      else
        FileUtils.rm_rf(configuration.cache_path)
      end
    end

    def reset
      @configuration = nil
      @model_registry = nil
      FixtureRegistry.reset
      FixtureCache.clear_memory_cache
    end
  end
end
