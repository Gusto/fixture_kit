# frozen_string_literal: true

module FixtureKit
  class Error < StandardError; end
  class DuplicateFixtureError < Error; end
  class DuplicateNameError < Error; end
  class CacheMissingError < Error; end
  class PregenerationError < Error; end
  class FixtureDefinitionNotFound < Error; end
  class ExposedRecordNotFound < Error; end

  autoload :VERSION,         File.expand_path("fixture_kit/version", __dir__)
  autoload :Configuration,   File.expand_path("fixture_kit/configuration", __dir__)
  autoload :Singleton,       File.expand_path("fixture_kit/singleton", __dir__)
  autoload :Fixture,         File.expand_path("fixture_kit/fixture", __dir__)
  autoload :DefinitionContext, File.expand_path("fixture_kit/definition_context", __dir__)
  autoload :Registry,        File.expand_path("fixture_kit/registry", __dir__)
  autoload :Repository,      File.expand_path("fixture_kit/repository", __dir__)
  autoload :SqlCapture,      File.expand_path("fixture_kit/sql_capture", __dir__)
  autoload :Cache,           File.expand_path("fixture_kit/cache", __dir__)
  autoload :Runner,          File.expand_path("fixture_kit/runner", __dir__)
  autoload :Generator,       File.expand_path("fixture_kit/generator", __dir__)
  autoload :TestCase,        File.expand_path("fixture_kit/test_case", __dir__)

  extend Singleton
end
