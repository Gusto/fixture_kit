# frozen_string_literal: true

require "active_support/core_ext/array/wrap"

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"

    include ConfigurationHelper

    attr_reader :fixture, :data

    def initialize(fixture)
      @fixture = fixture
    end

    def path
      file_cache.path
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
      data || file_cache.exists?
    end

    def clear_memory
      @data = nil
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      @data ||= file_cache.read
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

        @data = MemoryCache.new(
          records: generate_statements(captured_models),
          exposed: file_cache.serialize_exposed(fixture.definition.exposed)
        )
      end

      file_cache.write(data)
    end

    private

    def file_cache
      @file_cache ||= FileCache.new(
        File.join(configuration.cache_path, "#{identifier}.json")
      )
    end

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
  end
end
