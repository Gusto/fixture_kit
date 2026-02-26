# frozen_string_literal: true

module FixtureKit
  class Error < StandardError; end
  class DuplicateNameError < Error; end
  class InvalidFixtureDeclaration < Error; end
  class MultipleFixtures < Error; end
  class CacheMissingError < Error; end
  class FixtureDefinitionNotFound < Error; end
  class RunnerAlreadyStartedError < Error; end
  class CircularFixtureInheritance < Error; end

  autoload :VERSION, File.expand_path("fixture_kit/version", __dir__)
  autoload :Configuration, File.expand_path("fixture_kit/configuration", __dir__)
  autoload :Callbacks, File.expand_path("fixture_kit/callbacks", __dir__)
  autoload :ConfigurationHelper, File.expand_path("fixture_kit/configuration_helper", __dir__)
  autoload :Singleton, File.expand_path("fixture_kit/singleton", __dir__)
  autoload :Fixture, File.expand_path("fixture_kit/fixture", __dir__)
  autoload :Definition, File.expand_path("fixture_kit/definition", __dir__)
  autoload :Registry, File.expand_path("fixture_kit/registry", __dir__)
  autoload :Repository, File.expand_path("fixture_kit/repository", __dir__)
  autoload :SqlSubscriber, File.expand_path("fixture_kit/sql_subscriber", __dir__)
  autoload :Cache, File.expand_path("fixture_kit/cache", __dir__)
  autoload :FileCache, File.expand_path("fixture_kit/file_cache", __dir__)
  autoload :MemoryCache, File.expand_path("fixture_kit/memory_cache", __dir__)
  autoload :Runner, File.expand_path("fixture_kit/runner", __dir__)
  autoload :Adapter, File.expand_path("fixture_kit/adapter", __dir__)
  autoload :MinitestAdapter, File.expand_path("fixture_kit/adapters/minitest_adapter", __dir__)
  autoload :RSpecAdapter, File.expand_path("fixture_kit/adapters/rspec_adapter", __dir__)

  extend Singleton
end
