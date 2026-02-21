# frozen_string_literal: true

require "active_support/inflector"

module FixtureKit
  class FixtureRunner
    def self.run(fixture_name, force: false)
      new(fixture_name).run(force: force)
    end

    def initialize(fixture_name)
      @fixture_name = fixture_name
      @cache = FixtureCache.new(@fixture_name)
    end

    def run(force: false)
      if force
        execute_and_cache
      elsif @cache.exists?
        execute_from_cache
      elsif FixtureKit.configuration.autogenerate
        execute_and_cache
      else
        raise FixtureKit::CacheMissingError, <<~ERROR
          Cache not found for fixture '#{@fixture_name}'.

          Run your tests with autogenerate enabled to generate the cache:
            FixtureKit.configuration.autogenerate = true

          Or generate caches by running your test suite once with autogenerate enabled.
        ERROR
      end
    end

    private

    def execute_and_cache
      fixture = FixtureRegistry.fetch(@fixture_name)

      # Start capturing SQL
      capture = SqlCapture.new
      capture.start

      # Execute fixture definition - returns exposed records hash
      exposed = fixture.execute

      # Stop capturing and get affected models with their connections
      models_with_connections = capture.stop

      # Save cache
      @cache.save(
        models_with_connections: models_with_connections,
        exposed_mapping: build_exposed_mapping(exposed)
      )

      # Return FixtureSet from the exposed records
      FixtureSet.new(exposed)
    end

    def execute_from_cache
      @cache.load

      # Execute cached SQL statements by model
      @cache.records.each do |model_name, sql|
        next if sql.nil? || sql.empty?

        model = ActiveSupport::Inflector.constantize(model_name)
        connection = model.connection
        connection.execute(sql)
      end

      # Query exposed records and build FixtureSet
      @cache.build_fixture_set
    end

    def build_exposed_mapping(exposed)
      mapping = {}

      exposed.each do |name, record_or_records|
        if record_or_records.is_a?(Array)
          mapping[name.to_s] = record_or_records.map do |record|
            { "model" => record.class.name, "id" => record.id }
          end
        else
          record = record_or_records
          mapping[name.to_s] = { "model" => record.class.name, "id" => record.id }
        end
      end

      mapping
    end
  end
end
