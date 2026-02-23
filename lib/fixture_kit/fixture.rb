# frozen_string_literal: true

module FixtureKit
  class Fixture
    include ConfigurationHelper

    attr_reader :identifier, :definition

    def initialize(identifier, definition)
      @identifier = identifier
      @definition = definition
      @cache = Cache.new(self)
    end

    def cache(force: false)
      return if @cache.exists? && !force

      configuration.on_cache_save&.call(@cache.identifier)
      @cache.save
    end

    def mount
      unless @cache.exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{identifier}'"
      end

      configuration.on_cache_mount&.call(@cache.identifier)
      @cache.load
    end
  end
end
