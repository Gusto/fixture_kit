# frozen_string_literal: true

module FixtureKit
  class FixtureRunner
    def initialize(fixture_name, cache_path:, definition_file:, model_registry: nil)
      @fixture_name = fixture_name.to_sym
      @cache = FixtureCache.new(@fixture_name, cache_path)
      @definition_file = definition_file
      @model_registry = model_registry || default_model_registry
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
    # Wraps execution in a transaction that rolls back, so no data persists
    # Always regenerates the cache, even if one exists
    def generate_cache_only
      # Clear any existing cache for this fixture
      FixtureKit.clear_cache(@fixture_name.to_s)

      ActiveRecord::Base.transaction do
        execute_and_cache
        raise ActiveRecord::Rollback
      end

      true
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

      # Generate SQL statements grouped by model
      statements_by_model = generate_statements(tables_by_db)

      # Build exposed mapping for cache
      exposed_mapping = build_exposed_mapping(exposed)

      # Compute digest of definition file
      digest = FixtureCache.compute_digest(@definition_file)

      # Save cache with digest
      @cache.save(statements_by_model, exposed_mapping, digest: digest)

      # Return FixtureSet from the exposed records
      FixtureSet.new(exposed)
    end

    def execute_from_cache
      # Check if this is the first load (not in memory cache)
      first_load = !FixtureCache.in_memory?(@fixture_name)

      @cache.load

      # Validate digest on first disk load
      if first_load && FixtureKit.configuration.autogenerate
        current_digest = FixtureCache.compute_digest(@definition_file)
        if @cache.digest != current_digest
          # Digest mismatch - clear cache and regenerate
          FixtureKit.clear_cache(@fixture_name.to_s)
          return execute_and_cache
        end
      end

      # Execute cached SQL statements by model
      @cache.records.each do |model_name, sql|
        next if sql.nil? || sql.empty?

        model = ActiveSupport::Inflector.constantize(model_name)
        connection = model.connection
        connection.execute(sql)
      end

      # Query exposed records and build FixtureSet
      build_fixture_set_from_cache
    end

    def generate_statements(tables_by_db)
      statements_by_model = {}

      tables_by_db.each do |db_name, tables|
        tables.each do |table_name|
          model = model_for_table(table_name, db_name)
          next unless model

          model_name = model.name
          connection = model.connection
          columns = model.column_names

          # Collect all rows for this table
          rows = []
          model.order(:id).find_each do |record|
            row_values = columns.map do |col|
              value = record.read_attribute_before_type_cast(col)
              connection.quote(value)
            end
            rows << "(#{row_values.join(", ")})"
          end

          next if rows.empty?

          # Build batch INSERT statement
          sql = build_insert_sql(model, columns, rows, connection)
          statements_by_model[model_name] = sql
        end
      end

      statements_by_model
    end

    def build_insert_sql(model, columns, rows, connection)
      table_name = connection.quote_table_name(model.table_name)
      quoted_columns = columns.map { |c| connection.quote_column_name(c) }

      sql = "INSERT INTO #{table_name} (#{quoted_columns.join(", ")}) VALUES #{rows.join(", ")}"

      add_conflict_handling(sql, connection)
    end

    def add_conflict_handling(sql, connection)
      adapter_name = connection.adapter_name.downcase

      case adapter_name
      when /sqlite/
        sql.sub(/\AINSERT INTO/i, "INSERT OR IGNORE INTO")
      when /postgresql/, /postgis/
        "#{sql} ON CONFLICT DO NOTHING"
      when /mysql/, /trilogy/
        sql.sub(/\AINSERT INTO/i, "INSERT IGNORE INTO")
      else
        sql
      end
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
