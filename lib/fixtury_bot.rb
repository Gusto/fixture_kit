# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/string/inflections"

module FixturyBot
  class Error < StandardError; end
  class DuplicateFixturyError < Error; end
  class DuplicateNameError < Error; end
  class StaleFixturesError < Error; end

  autoload :VERSION,           "fixtury_bot/version"
  autoload :Configuration,     "fixtury_bot/configuration"
  autoload :Singleton,         "fixtury_bot/singleton"
  autoload :Fixtury,          "fixtury_bot/fixtury"
  autoload :FixturyRegistry,  "fixtury_bot/fixtury_registry"
  autoload :RecordTracker,     "fixtury_bot/record_tracker"
  autoload :FixtureSerializer, "fixtury_bot/fixture_serializer"
  autoload :FixtureLoader,     "fixtury_bot/fixture_loader"
  autoload :Validator,         "fixtury_bot/validator"

  extend Singleton
end

require "fixtury_bot/railtie" if defined?(Rails::Railtie)
