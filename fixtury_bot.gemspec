# frozen_string_literal: true

require_relative "lib/fixtury_bot/version"

Gem::Specification.new do |spec|
  spec.name = "fixtury_bot"
  spec.version = FixturyBot::VERSION
  spec.authors = ["Ngan Pham"]
  spec.email = ["ngan.pham@gusto.com"]

  spec.summary = "Generate Rails fixtures from Factory Bot definitions"
  spec.description = "FixturyBot combines the maintainability of Factory Bot with the speed of Rails fixtures. Define fixturys using Factory Bot syntax, generate fixture files, and load those fixtures in your tests for fast, reliable test data."
  spec.homepage = "https://github.com/Gusto/fixtury_bot"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb", "exe/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["fixtury_bot", "fixtury"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 8.0"
  spec.add_dependency "activerecord", ">= 8.0"
  spec.add_dependency "factory_bot", ">= 5.0"

  spec.add_development_dependency "irb"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec-rails", "~> 7.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"
  spec.add_development_dependency "railties", ">= 8.0"
end
