# frozen_string_literal: true

module FixtureKit
  class Registry
    include ConfigurationHelper

    def initialize
      @declarations = {}
      @fixtures = {}
    end

    def add(scope, name_or_block)
      if @declarations.key?(scope)
        raise FixtureKit::MultipleFixtures, "cannot load multiple fixtures in the same context"
      end

      @declarations[scope] =
        case name_or_block
        when String
          fetch_named_fixture(name_or_block)
        when Proc
          fetch_anonymous_fixture(scope, name_or_block)
        else
          raise FixtureKit::InvalidFixtureDeclaration, "unsupported fixture declaration type: #{name_or_block.class}"
        end
    end

    def fixtures
      @fixtures.values
    end

    private

    def fetch_named_fixture(name)
      @fixtures[name] ||= Fixture.new(name, load_named_definition(name))
    end

    def fetch_anonymous_fixture(scope, definition)
      @fixtures[scope] ||= Fixture.new(scope, Definition.new(&definition))
    end

    def load_named_definition(name)
      file_path = File.expand_path(File.join(configuration.fixture_path, "#{name}.rb"))

      unless File.file?(file_path)
        raise FixtureKit::FixtureDefinitionNotFound,
          "cannot find fixture definition file for '#{name}' at '#{file_path}'"
      end

      definition = eval(File.read(file_path), TOPLEVEL_BINDING.dup, file_path)
      return definition if definition.is_a?(Definition)

      raise FixtureKit::FixtureDefinitionNotFound, "cannot find fixture definition at '#{file_path}'"
    end
  end
end
