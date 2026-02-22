# frozen_string_literal: true

module FixtureKit
  class Fixture
    include ConfigurationHelper

    attr_reader :name, :path

    def initialize(name, path)
      @name = name
      @path = path
      @cache = Cache.new(self, definition)
    end

    def cache(force: false)
      return if @cache.exists? && !force

      configuration.on_cache&.call(name)
      @cache.save
    end

    def mount
      unless @cache.exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{name}'"
      end

      @cache.load
    end

    private

    def definition
      @definition ||= begin
        definition = eval(File.read(@path), TOPLEVEL_BINDING.dup, @path)
        raise FixtureKit::FixtureDefinitionNotFound, "Could not find fixture definition at '#{@path}'" unless definition.is_a?(Definition)
        definition
      end
    end
  end
end
