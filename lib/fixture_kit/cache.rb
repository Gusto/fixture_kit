# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/core_ext/array/wrap"
require "active_support/inflector"

module FixtureKit
  class Cache
    include ConfigurationHelper

    attr_reader :fixture

    def initialize(fixture, definition)
      @fixture = fixture
      @definition = definition
    end

    def path
      File.join(configuration.cache_path, "#{fixture.name}.json")
    end

    def exists?
      @data || File.exist?(path)
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.name}'"
      end

      @data ||= JSON.parse(File.read(path))
      @data.fetch("records").each do |model_name, sql|
        model = ActiveSupport::Inflector.constantize(model_name)
        model.connection.execute(sql)
      end

      build_repository(@data.fetch("exposed"))
    end

    def save
      FixtureKit.runner.isolator.run do
        models = SqlSubscriber.capture do
          @definition.evaluate
        end

        @data = {
          "records" => generate_statements(models),
          "exposed" => build_exposed_mapping(@definition.exposed)
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
        "Could not find #{model_name} with id=#{id} for exposed record '#{exposed_name}' in fixture '#{@fixture.name}'"
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

        next if rows.empty?

        sql = build_insert_sql(model.table_name, columns, rows, model.connection)
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

    def build_exposed_mapping(exposed)
      exposed.each_with_object({}) do |(name, value), hash|
        was_array = value.is_a?(Array)
        records = Array.wrap(value).map { |record| { "model" => record.class.name, "id" => record.id } }
        hash[name] = was_array ? records : records.first
      end
    end
  end
end
