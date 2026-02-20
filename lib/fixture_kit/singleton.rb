# frozen_string_literal: true

require "pathname"

module FixtureKit
  module Singleton
    def configure
      yield(configuration) if block_given?
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

    def reset
      @configuration = nil
      FixtureRegistry.reset
      FixtureCache.clear_memory_cache
    end
  end
end
