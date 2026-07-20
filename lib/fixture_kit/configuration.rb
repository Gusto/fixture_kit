# frozen_string_literal: true

module FixtureKit
  class Configuration
    attr_accessor :fixture_path
    attr_accessor :cache_path
    attr_reader :adapter_options, :callbacks, :coders

    def initialize
      @fixture_path = "fixture_kit"
      @cache_path = "tmp/cache/fixture_kit"
      @adapter_class = MinitestAdapter
      @adapter_options = {}
      @callbacks = Callbacks.new
      @coders = Set.new([ActiveRecordCoder])
    end

    def register(coder)
      @coders.add(coder)
    end

    def adapter(adapter_class = nil, **options)
      return @adapter_class if adapter_class.nil? && options.empty?

      @adapter_class = adapter_class
      @adapter_options = options
    end

    # Fires when a fixture is registered, before any caching. The block receives the
    # Event and the declaring scope (the example group for the RSpec adapter).
    def on_register(&block)
      callbacks.register(:register, &block)
    end

    def on_cache_save(&block)
      callbacks.register(:cache_save, &block)
    end

    def on_cache_saved(&block)
      callbacks.register(:cache_saved, &block)
    end

    def on_cache_mount(&block)
      callbacks.register(:cache_mount, &block)
    end

    def on_cache_mounted(&block)
      callbacks.register(:cache_mounted, &block)
    end
  end
end
