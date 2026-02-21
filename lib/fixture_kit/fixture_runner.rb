# frozen_string_literal: true

require "active_support/inflector"

module FixtureKit
  class FixtureRunner
    def initialize(fixture_name)
      @fixture_name = fixture_name.to_sym
      @cache = FixtureCache.new(@fixture_name)
    end

    def run
      if @cache.exists?
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

    # Generate cache only (used for pregeneration in before(:suite))
    # Wraps execution in the configured generator lifecycle.
    # The default generator uses ActiveRecord::TestFixtures transactions.
    # Entry points (like `fixture_kit/rspec`) can install richer generators.
    # Always regenerates the cache, even if one exists
    def generate_cache_only
      # Clear any existing cache for this fixture
      FixtureCache.clear(@fixture_name.to_s)

      FixtureKit.configuration.generator.run do
        execute_and_cache
      end

      true
    end

    private

    def execute_and_cache
      fixture = FixtureRegistry.find(@fixture_name) || load_fixture_definition
      raise ArgumentError, "Fixture '#{@fixture_name}' not found" unless fixture

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

    def load_fixture_definition
      fixture_path = FixtureKit.configuration.fixture_path
      file_path = File.expand_path(File.join(fixture_path, "#{@fixture_name}.rb"))
      load file_path
      FixtureRegistry.find(@fixture_name)
    rescue LoadError, Errno::ENOENT
      nil
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
