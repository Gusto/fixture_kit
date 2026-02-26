# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/core_ext/array/wrap"
require "active_support/inflector"

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"
    MemoryData = Data.define(:records, :exposed)

    include ConfigurationHelper

    attr_reader :fixture, :data

    def initialize(fixture)
      @fixture = fixture
    end

    def path
      File.join(configuration.cache_path, "#{identifier}.json")
    end

    def identifier
      @identifier ||= begin
        raw_identifier = fixture.identifier
        if raw_identifier.is_a?(String)
          raw_identifier
        else
          File.join(ANONYMOUS_DIRECTORY, FixtureKit.runner.adapter.identifier_for(raw_identifier))
        end
      end
    end

    def exists?
      data || File.exist?(path)
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      @data ||= load_memory_data
      statements_by_connection(data.records).each do |connection, statements|
        connection.disable_referential_integrity do
          # execute_batch is private in current supported Rails versions.
          # This should be revisited when Rails 8.2 makes it public.
          connection.__send__(:execute_batch, statements, "FixtureKit Load")
        end
      end

      Repository.new(data.exposed)
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        captured_models = SqlSubscriber.capture do
          fixture.definition.evaluate(context, parent: fixture.parent&.mount)
        end

        if fixture.parent
          captured_models.concat(fixture.parent.cache.data.records.keys)
        end

        @data = MemoryData.new(
          records: generate_statements(captured_models),
          exposed: build_exposed_mapping(fixture.definition.exposed)
        )
      end

      save_file_data
    end

    private

    def generate_statements(models)
      models.uniq.each_with_object({}) do |model, statements|
        columns = model.column_names

        rows = []
        model.unscoped.order(:id).find_each do |record|
          row_values = columns.map do |col|
            value = record.read_attribute_before_type_cast(col)
            model.connection.quote(value)
          end
          rows << "(#{row_values.join(", ")})"
        end

        sql = rows.empty? ? nil : build_insert_sql(model.table_name, columns, rows, model.connection)
        statements[model] = sql
      end
    end

    def build_delete_sql(model)
      "DELETE FROM #{model.quoted_table_name}"
    end

    def build_insert_sql(table_name, columns, rows, connection)
      quoted_table = connection.quote_table_name(table_name)
      quoted_columns = columns.map { |c| connection.quote_column_name(c) }

      "INSERT INTO #{quoted_table} (#{quoted_columns.join(", ")}) VALUES #{rows.join(", ")}"
    end

    def build_exposed_mapping(exposed)
      exposed.each_with_object({}) do |(name, record), hash|
        if record.is_a?(Array)
          hash[name] = record.map { |record| { record.class => record.id } }
        else
          hash[name] = { record.class => record.id }
        end
      end
    end

    def statements_by_connection(records)
      deleted_tables = Set.new

      records.each_with_object({}) do |(model, sql), grouped|
        connection = model.connection
        grouped[connection] ||= []

        table_key = [connection, model.table_name]
        if deleted_tables.add?(table_key)
          grouped[connection] << build_delete_sql(model)
        end

        grouped[connection] << sql if sql
      end
    end

    def load_memory_data
      file_data = JSON.parse(File.read(path))
      records = file_data.fetch("records").transform_keys do |model_name|
        ActiveSupport::Inflector.constantize(model_name)
      end

      exposed = file_data.fetch("exposed").each_with_object({}) do |(name, value), hash|
        if value.is_a?(Array)
          hash[name.to_sym] = value.map { |r| { ActiveSupport::Inflector.constantize(r.keys.first) => r.values.first } }
        else
          hash[name.to_sym] = { ActiveSupport::Inflector.constantize(value.keys.first) => value.values.first }
        end
      end

      MemoryData.new(records: records, exposed: exposed)
    end

    def save_file_data
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(data.to_h))
    end
  end
end
