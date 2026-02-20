# frozen_string_literal: true

module FixtureKit
  class Error < StandardError; end
  class DuplicateFixtureError < Error; end
  class DuplicateNameError < Error; end
  class CacheMissingError < Error; end
  class ExposedRecordNotFound < Error; end

  autoload :VERSION,         File.expand_path("fixture_kit/version", __dir__)
  autoload :Configuration,   File.expand_path("fixture_kit/configuration", __dir__)
  autoload :Singleton,       File.expand_path("fixture_kit/singleton", __dir__)
  autoload :Fixture,         File.expand_path("fixture_kit/fixture", __dir__)
  autoload :FixtureContext,  File.expand_path("fixture_kit/fixture_context", __dir__)
  autoload :FixtureRegistry, File.expand_path("fixture_kit/fixture_registry", __dir__)
  autoload :FixtureSet,      File.expand_path("fixture_kit/fixture_set", __dir__)
  autoload :SqlCapture,      File.expand_path("fixture_kit/sql_capture", __dir__)
  autoload :FixtureCache,    File.expand_path("fixture_kit/fixture_cache", __dir__)
  autoload :FixtureRunner,   File.expand_path("fixture_kit/fixture_runner", __dir__)
  autoload :TransactionalHarness, File.expand_path("fixture_kit/transactional_harness", __dir__)

  extend Singleton
end
