# frozen_string_literal: true

require "stringio"

module FixturyBot
  module Singleton
    def configure
      @configuration = Configuration.new
      yield(@configuration) if block_given?
      self
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def define(name, &block)
      fixtury = Fixtury.new(name, &block)
      FixturyRegistry.register(fixtury)
      fixtury
    end

    # Load a fixtury's fixtures into the database and return a FixtureSet.
    # Uses cached INSERT statements if available, otherwise executes fixtury and caches.
    def load_fixtury(name)
      runner = FixturyRunner.new(
        name,
        cache_path: configuration.cache_path,
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

    # Clear the fixtury cache for a specific fixtury or all
    def clear_cache(fixtury_name = nil)
      if fixtury_name
        cache_file = File.join(configuration.cache_path, "#{fixtury_name}.yml")
        FileUtils.rm_f(cache_file)
      else
        FileUtils.rm_rf(configuration.cache_path)
      end
    end

    # Execute a block within nested transactions on all provided database connections
    def with_transactions(connections, &block)
      if connections.empty?
        yield
      else
        conn = connections.first
        conn.transaction do
          with_transactions(connections[1..], &block)
          raise ActiveRecord::Rollback
        end
      end
    end

    def reset
      @configuration = nil
      @model_registry = nil
      FixturyRegistry.reset
    end
  end
end
