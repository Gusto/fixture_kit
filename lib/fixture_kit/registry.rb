# frozen_string_literal: true

require "pathname"

module FixtureKit
  class Registry
    def initialize
      @registry = {}
    end

    def add(name)
      return @registry[name] if @registry.key?(name)

      file_path = fixture_file_path(name)
      unless File.file?(file_path)
        raise FixtureKit::FixtureDefinitionNotFound,
          "Could not find fixture definition file for '#{name}' at '#{file_path}'"
      end

      @registry[name] = Fixture.new(name, file_path)
    end

    def fixtures
      @registry.values
    end

    private

    def fixture_file_path(name)
      File.expand_path(File.join(FixtureKit.runner.configuration.fixture_path, "#{name}.rb"))
    end
  end
end
