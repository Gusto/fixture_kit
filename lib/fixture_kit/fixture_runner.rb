# frozen_string_literal: true

module FixtureKit
  class FixtureRunner
    def initialize(fixture_name, cache_path:, model_registry: nil)
      @fixture_name = fixture_name.to_sym
      @cache = FixtureCache.new(@fixture_name, cache_path)
      @model_registry = model_registry || default_model_registry
    end

    def run
      if @cache.exists?
        replay_from_cache
      else
        execute_and_cache
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

      # Execute fixture definition
      result = fixture.execute

      # Stop capturing and get affected tables
      tables_by_db = capture.stop

      # Generate records from affected tables (grouped by model)
      records_by_model = generate_records(tables_by_db)

      # Build exposed mapping
      exposed_mapping = build_exposed_mapping(result)

      # Save cache
      @cache.save(records_by_model, exposed_mapping)

      # Build and return FixtureSet from the records we just created
      build_fixture_set_from_result(result)
    end

    def replay_from_cache
      @cache.load

      # Insert cached records using upsert_all (skips duplicates by "updating" with same values)
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

    def build_exposed_mapping(result)
      mapping = {}

      result.exposed.each do |name, fixture_name_or_names|
        if fixture_name_or_names.is_a?(Array)
          # Array of fixture names from create_list
          records = fixture_name_or_names.map do |fixture_name|
            entry = result.records.find { |e| e.fixture_name.to_s == fixture_name.to_s }
            next unless entry

            { "model" => entry.record.class.name, "id" => entry.record.id }
          end.compact
          mapping[name.to_s] = records
        else
          # Single fixture name
          entry = result.records.find { |e| e.fixture_name.to_s == fixture_name_or_names.to_s }
          if entry
            mapping[name.to_s] = { "model" => entry.record.class.name, "id" => entry.record.id }
          end
        end
      end

      mapping
    end

    def build_fixture_set_from_result(result)
      exposed_records = {}

      result.exposed.each do |name, fixture_name_or_names|
        if fixture_name_or_names.is_a?(Array)
          records = fixture_name_or_names.map do |fixture_name|
            entry = result.records.find { |e| e.fixture_name.to_s == fixture_name.to_s }
            entry&.record
          end.compact
          exposed_records[name.to_sym] = records
        else
          entry = result.records.find { |e| e.fixture_name.to_s == fixture_name_or_names.to_s }
          exposed_records[name.to_sym] = entry&.record
        end
      end

      FixtureSet.new(exposed_records)
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
      # Try to find model from registry first
      @model_registry.dig(db_name, table_name) || infer_model(table_name)
    end

    def infer_model(table_name)
      ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(table_name))
    rescue NameError
      nil
    end

    def default_model_registry
      # Build a registry of table_name => model_class grouped by database
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
