# frozen_string_literal: true

require "active_support"
require "active_support/inflector"

module FixturyBot
  class Error < StandardError; end
  class DuplicateFixturyError < Error; end
  class DuplicateNameError < Error; end

  autoload :VERSION,           File.expand_path("fixtury_bot/version", __dir__)
  autoload :Configuration,     File.expand_path("fixtury_bot/configuration", __dir__)
  autoload :Singleton,         File.expand_path("fixtury_bot/singleton", __dir__)
  autoload :Fixtury,           File.expand_path("fixtury_bot/fixtury", __dir__)
  autoload :FixturyRegistry,   File.expand_path("fixtury_bot/fixtury_registry", __dir__)
  autoload :RecordTracker,     File.expand_path("fixtury_bot/record_tracker", __dir__)
  autoload :FixtureSet,        File.expand_path("fixtury_bot/fixture_set", __dir__)
  autoload :SqlCapture,        File.expand_path("fixtury_bot/sql_capture", __dir__)
  autoload :FixturyCache,      File.expand_path("fixtury_bot/fixtury_cache", __dir__)
  autoload :FixturyRunner,     File.expand_path("fixtury_bot/fixtury_runner", __dir__)

  extend Singleton
end

require_relative "fixtury_bot/railtie" if defined?(Rails::Railtie)
