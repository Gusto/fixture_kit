# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/core_ext/array/wrap"
require "active_support/inflector"

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"

    include ConfigurationHelper

    attr_reader :fixture

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
          FixtureKit.runner.adapter.identifier_for(raw_identifier)
        end
      end
    end

    def exists?
      @data || File.exist?(path)
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      @data ||= JSON.parse(File.read(path))
      @data.fetch("records").each do |model_name, sql|
        model = ActiveSupport::Inflector.constantize(model_name)
        connection = model.connection
        connection.disable_referential_integrity do
          # execute_batch is private in current supported Rails versions.
          # This should be revisited when Rails 8.2 makes it public.
          connection.__send__(:execute_batch, [build_delete_sql(model), sql].compact, "FixtureKit Load")
        end
      end

      build_repository(@data.fetch("exposed"))
    end

    def save
      FixtureKit.runner.adapter.execute do
        models = SqlSubscriber.capture do
          fixture.definition.evaluate
        end

        @data = {
          "records" => generate_statements(models),
          "exposed" => build_exposed_mapping(fixture.definition.exposed)
        }
      end

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(@data))
    end

    # Query exposed records from the database and return a Repository.
    def build_repository(exposed)
      exposed_records = exposed.each_with_object({}) do |(name, value), hash|
        was_array = value.is_a?(Array)
        records = Array.wrap(value).map { |record_info| find_exposed_record(record_info.fetch("model"), record_info.fetch("id"), name) }
        hash[name.to_sym] = was_array ? records : records.first
      end

      Repository.new(exposed_records)
    end

    private

    def find_exposed_record(model_name, id, exposed_name)
      model = ActiveSupport::Inflector.constantize(model_name)
      model.find(id)
    rescue ActiveRecord::RecordNotFound
      raise FixtureKit::ExposedRecordNotFound,
        "Could not find #{model_name} with id=#{id} for exposed record '#{exposed_name}' in fixture '#{@fixture.identifier}'"
    end

    def generate_statements(models)
      statements_by_model = {}

      models.each do |model|
        columns = model.column_names

        rows = []
        model.order(:id).find_each do |record|
          row_values = columns.map do |col|
            value = record.read_attribute_before_type_cast(col)
            model.connection.quote(value)
          end
          rows << "(#{row_values.join(", ")})"
        end

        sql = rows.empty? ? nil : build_insert_sql(model.table_name, columns, rows, model.connection)
        statements_by_model[model.name] = sql
      end

      statements_by_model
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
      exposed.each_with_object({}) do |(name, value), hash|
        was_array = value.is_a?(Array)
        records = Array.wrap(value).map { |record| { "model" => record.class.name, "id" => record.id } }
        hash[name] = was_array ? records : records.first
      end
    end
  end
end
