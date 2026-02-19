# frozen_string_literal: true

module FixtureKit
  class FixtureRunner
    def initialize(fixture_name, cache_path:, model_registry: nil)
      @fixture_name = fixture_name.to_sym
      @cache = FixtureCache.new(@fixture_name, cache_path)
      @model_registry = model_registry || default_model_registry
    end

    def run
      if FixtureKit.configuration.autogenerate
        # Always regenerate cache when autogenerate is true
        execute_and_cache
      else
        # When autogenerate is false, cache must exist
        unless @cache.exists?
          raise FixtureKit::CacheMissingError, <<~ERROR
            Cache not found for fixture '#{@fixture_name}'.

            Run your tests with autogenerate enabled to generate the cache:
              FixtureKit.configuration.autogenerate = true

            Or generate caches by running your test suite once with autogenerate enabled.
          ERROR
        end
        replay_from_cache
      end
    end

    private

    def execute_and_cache
      fixture = FixtureRegistry.find(@fixture_name)
      raise ArgumentError, "Fixture '#{@fixture_name}' not found" unless fixture

      # Start capturing SQL
      capture = SqlCapture.new
      capture.start

      # Run setup hook if configured
      FixtureKit.configuration.setup&.call

      # Execute fixture definition - returns exposed records hash
      exposed = fixture.execute

      # Stop capturing and get affected tables
      tables_by_db = capture.stop

      # Generate records from affected tables (grouped by model)
      records_by_model = generate_records(tables_by_db)

      # Build exposed mapping for cache
      exposed_mapping = build_exposed_mapping(exposed)

      # Save cache
      @cache.save(records_by_model, exposed_mapping)

      # Return FixtureSet from the exposed records
      FixtureSet.new(exposed)
    end

    def replay_from_cache
      @cache.load

      # Insert cached records using upsert_all (skips duplicates)
      @cache.records.each do |model_name, attributes_array|
        next if attributes_array.empty?

        model = ActiveSupport::Inflector.constantize(model_name)
        model.upsert_all(attributes_array, on_duplicate: :skip)
      end

      # Query exposed records and build FixtureSet
      build_fixture_set_from_cache
    end

    def generate_records(tables_by_db)
      records_by_model = {}

      tables_by_db.each do |db_name, tables|
        tables.each do |table_name|
          model = model_for_table(table_name, db_name)
          next unless model

          model_name = model.name
          records_by_model[model_name] ||= []

          model.find_each do |record|
            # Only use actual database columns, not virtual attributes
            columns = model.column_names & record.attributes.keys
            records_by_model[model_name] << columns.to_h { |col| [col, record.read_attribute_before_type_cast(col)] }
          end
        end
      end

      records_by_model
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

    def build_fixture_set_from_cache
      exposed_records = {}

      @cache.exposed.each do |name, value|
        if value.is_a?(Array)
          records = value.map do |record_info|
            model = ActiveSupport::Inflector.constantize(record_info["model"])
            model.find_by(id: record_info["id"])
          end.compact
          exposed_records[name.to_sym] = records
        else
          model = ActiveSupport::Inflector.constantize(value["model"])
          exposed_records[name.to_sym] = model.find_by(id: value["id"])
        end
      end

      FixtureSet.new(exposed_records)
    end

    def model_for_table(table_name, db_name)
      @model_registry.dig(db_name, table_name) || infer_model(table_name)
    end

    def infer_model(table_name)
      ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(table_name))
    rescue NameError
      nil
    end

    def default_model_registry
      registry = Hash.new { |h, k| h[k] = {} }

      ActiveRecord::Base.descendants.each do |model|
        next if model.abstract_class?
        next unless model.table_exists?

        db_name = model.connection_db_config.name
        registry[db_name][model.table_name] = model
      end

      registry
    end
  end
end
