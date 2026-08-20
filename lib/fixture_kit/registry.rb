# frozen_string_literal: true

module FixtureKit
  class Registry
    include ConfigurationHelper

    def initialize
      @declarations = {}
      @fixtures = {}
      @resolving = []
      @cache_owners = {}
    end

    def add(name_or_definition, scope = nil)
      fixture =
        case name_or_definition
        when String
          fetch_named_fixture(name_or_definition)
        when Definition
          raise ArgumentError, "scope is required for anonymous fixture declarations" unless scope
          fetch_anonymous_fixture(scope, name_or_definition)
        else
          raise FixtureKit::InvalidFixtureDeclaration, "unsupported fixture declaration type: #{name_or_definition.class}"
        end

      if scope
        raise FixtureKit::MultipleFixtures, "cannot load multiple fixtures in the same context" if @declarations.key?(scope)
        @declarations[scope] = fixture
      end

      fixture
    end

    def fixtures
      @fixtures.values
    end

    # Fixtures sharing a cache identifier share a cache file: the second one to
    # generate finds the file already written, skips generation, and mounts the
    # other's records. That is only safe when both declarations are the same, so
    # anything else has to fail here -- otherwise it surfaces as a confusing
    # NoMethodError on Repository, or not at all when both expose the same names.
    # Identifiers are derived from the declaration site, so this is a backstop
    # against a digest collision or a regression in that derivation.
    def claim_cache_identifier(fixture)
      owner = (@cache_owners[fixture.cache.identifier] ||= fixture)
      return if owner.equal?(fixture)
      return if owner.definition.fingerprint == fixture.definition.fingerprint

      raise FixtureKit::CacheIdentifierCollision,
        "fixtures declared at #{owner.definition.location} and #{fixture.definition.location} " \
        "both resolve to the cache identifier '#{fixture.cache.identifier}'"
    end

    private

    def fetch_named_fixture(name)
      return @fixtures[name] if @fixtures.key?(name)

      if @resolving.include?(name)
        chain = @resolving + [name]
        start = chain.index(name)
        raise FixtureKit::CircularFixtureInheritance,
          "circular fixture inheritance detected: #{chain[start..].join(" -> ")}"
      end

      @resolving.push(name)
      @fixtures[name] = Fixture.new(name, load_named_definition(name))
      @resolving.pop
      @fixtures[name]
    end

    def fetch_anonymous_fixture(scope, definition)
      @fixtures[scope] ||= Fixture.new(scope, definition)
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
