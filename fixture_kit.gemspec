# frozen_string_literal: true

require_relative "lib/fixture_kit/version"

Gem::Specification.new do |spec|
  spec.name = "fixture_kit"
  spec.version = FixtureKit::VERSION
  spec.authors = ["Ngan Pham"]
  spec.email = ["ngan.pham@gusto.com"]

  spec.summary = "Fast test fixtures with SQL caching"
  spec.description = "FixtureKit provides lightning-fast test setup by caching database records. Define fixtures using any tool (FactoryBot, raw ActiveRecord, etc.), and FixtureKit caches the SQL to replay in subsequent test runs."
  spec.homepage = "https://github.com/Gusto/fixture_kit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 8.0"
  spec.add_dependency "activerecord", ">= 8.0"

  spec.add_development_dependency "irb"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "railties"
end
