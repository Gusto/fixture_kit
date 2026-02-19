# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/core_ext/array/wrap"
require "active_support/inflector"

module FixtureKit
  class FixtureCache
    # In-memory cache to avoid re-reading/parsing JSON for every test
    @memory_cache = {}

    class << self
      attr_accessor :memory_cache

      def clear_memory_cache(fixture_name = nil)
        if fixture_name
          @memory_cache.delete(fixture_name.to_s)
        else
          @memory_cache.clear
        end
      end

      # Clear fixture cache (both memory and disk)
      def clear(fixture_name = nil)
        clear_memory_cache(fixture_name)

        cache_path = FixtureKit.configuration.cache_path
        if fixture_name
          cache_file = File.join(cache_path, "#{fixture_name}.json")
          FileUtils.rm_f(cache_file)
        else
          FileUtils.rm_rf(cache_path)
        end
      end

      # Pre-generate caches for all fixtures.
      # Each fixture is generated in a transaction that rolls back, so no data persists.
      def pregenerate_all
        fixture_path = FixtureKit.configuration.fixture_path

        # First, load all fixture files to register them
        FixtureRegistry.load_definitions(fixture_path)

        # Then iterate over the registry and generate caches
        FixtureRegistry.all_names.each do |name|
          runner = FixtureRunner.new(name)
          runner.generate_cache_only
        end
      end
    end

    attr_reader :records, :exposed

    def initialize(fixture_name)
      @fixture_name = fixture_name.to_s
      @records = {}
      @exposed = {}
    end

    def cache_file_path
      cache_path = FixtureKit.configuration.cache_path
      File.join(cache_path, "#{@fixture_name}.json")
    end

    def exists?
      # Check in-memory cache first, then disk
      self.class.memory_cache.key?(@fixture_name) || File.exist?(cache_file_path)
    end

    def load
      # Check in-memory cache first
      if self.class.memory_cache.key?(@fixture_name)
        data = self.class.memory_cache[@fixture_name]
        @records = data.fetch("records")
        @exposed = data.fetch("exposed")
        return true
      end

      # Fall back to disk
      return false unless File.exist?(cache_file_path)

      data = JSON.parse(File.read(cache_file_path))
      @records = data.fetch("records")
      @exposed = data.fetch("exposed")

      # Store in memory for subsequent loads
      self.class.memory_cache[@fixture_name] = data

      true
    end

    def save(models_with_connections:, exposed_mapping:)
      @records = generate_statements(models_with_connections)
      @exposed = exposed_mapping

      FileUtils.mkdir_p(File.dirname(cache_file_path))

      data = {
        "records" => @records,
        "exposed" => @exposed
      }

      # Store in memory cache
      self.class.memory_cache[@fixture_name] = data

      File.write(cache_file_path, JSON.pretty_generate(data))
    end

    # Query exposed records from the database and return a FixtureSet
    def build_fixture_set
      exposed_records = @exposed.each_with_object({}) do |(name, value), hash|
        was_array = value.is_a?(Array)
        records = Array.wrap(value).map { |record_info| find_exposed_record(record_info.fetch("model"), record_info.fetch("id"), name) }
        hash[name.to_sym] = was_array ? records : records.first
      end

      FixtureSet.new(exposed_records)
    end

    private

    def find_exposed_record(model_name, id, exposed_name)
      model = ActiveSupport::Inflector.constantize(model_name)
      model.find(id)
    rescue ActiveRecord::RecordNotFound
      raise FixtureKit::ExposedRecordNotFound,
        "Could not find #{model_name} with id=#{id} for exposed record '#{exposed_name}' in fixture '#{@fixture_name}'"
    end

    def generate_statements(models_with_connections)
      statements_by_model = {}

      models_with_connections.each do |model, connection|
        columns = model.column_names

        rows = []
        model.order(:id).find_each do |record|
          row_values = columns.map do |col|
            value = record.read_attribute_before_type_cast(col)
            connection.quote(value)
          end
          rows << "(#{row_values.join(", ")})"
        end

        next if rows.empty?

        sql = build_insert_sql(model.table_name, columns, rows, connection)
        statements_by_model[model.name] = sql
      end

      statements_by_model
    end

    def build_insert_sql(table_name, columns, rows, connection)
      quoted_table = connection.quote_table_name(table_name)
      quoted_columns = columns.map { |c| connection.quote_column_name(c) }

      sql = "INSERT INTO #{quoted_table} (#{quoted_columns.join(", ")}) VALUES #{rows.join(", ")}"

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
  end
end
