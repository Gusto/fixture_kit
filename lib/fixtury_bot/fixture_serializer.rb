# frozen_string_literal: true

require "yaml"
require "fileutils"

module FixturyBot
  class FixtureSerializer
    TIMESTAMP_COLUMNS = %w[created_at updated_at created_on updated_on].freeze
    EXCLUDED_COLUMNS = %w[id created_at updated_at created_on updated_on].freeze

    def initialize(records, fixtury_name, fixtures_path, exposed: {}, source_digest: nil)
      @records = records
      @fixtury_name = fixtury_name
      @fixtures_path = fixtures_path
      @exposed = exposed
      @source_digest = source_digest
      @record_lookup = build_record_lookup
    end

    def serialize
      fixtury_path = File.join(@fixtures_path, @fixtury_name.to_s)
      FileUtils.rm_rf(fixtury_path)
      FileUtils.mkdir_p(fixtury_path)

      metadata = {}

      records_by_database.each do |database_name, entries|
        database_path = File.join(fixtury_path, database_name)
        FileUtils.mkdir_p(database_path)

        representative_model = entries.first.record.class
        metadata[database_name] = representative_model.name

        entries_by_table = entries.group_by { |e| e.record.class.table_name }

        entries_by_table.each do |table_name, table_entries|
          fixture_data = {}

          table_entries.each do |entry|
            fixture_name = entry.fixture_name.to_s
            fixture_data[fixture_name] = serialize_record(entry.record)
          end

          file_path = File.join(database_path, "#{table_name}.yml")
          File.write(file_path, fixture_data.to_yaml)
        end
      end

      full_metadata = { "databases" => metadata }
      full_metadata["exposed"] = serialize_exposed if @exposed.any?
      full_metadata["source_digest"] = @source_digest if @source_digest

      metadata_path = File.join(fixtury_path, ".fixtury_bot.yml")
      File.write(metadata_path, full_metadata.to_yaml)

      fixtury_path
    end

    private

    def serialize_exposed
      @exposed.transform_keys(&:to_s).transform_values do |value|
        value.is_a?(Array) ? value.map(&:to_s) : value.to_s
      end
    end

    def records_by_database
      @records.group_by(&:database_name)
    end

    def build_record_lookup
      lookup = Hash.new { |h, k| h[k] = {} }

      @records.each do |entry|
        model_class = entry.record.class
        lookup[model_class][entry.record.id] = entry.fixture_name
      end

      lookup
    end

    def serialize_record(record)
      attributes = record.attributes.except(*EXCLUDED_COLUMNS)
      serialized = {}

      # Pre-calculate which polymorphic type columns should be skipped
      polymorphic_type_columns = find_resolvable_polymorphic_types(record, attributes)

      attributes.each do |key, value|
        next if value.nil?
        next if polymorphic_type_columns.include?(key)

        if foreign_key?(record.class, key)
          resolved = resolve_association(record, key, value)
          if resolved
            serialized.merge!(resolved)
            next
          end
        end

        serialized[key] = serialize_value(value)
      end

      serialized
    end

    def find_resolvable_polymorphic_types(record, attributes)
      type_columns = []

      attributes.each do |key, value|
        next unless key.end_with?("_id") && value

        association_name = key.sub(/_id\z/, "")
        association = record.class.reflect_on_association(association_name)
        next unless association&.polymorphic?

        type_column = "#{association_name}_type"
        type_value = record[type_column]
        next unless type_value

        model_class = type_value.constantize
        fixture_name = @record_lookup[model_class][value]
        type_columns << type_column if fixture_name
      end

      type_columns
    end

    def foreign_key?(model_class, attribute)
      attribute.end_with?("_id")
    end

    def resolve_association(record, foreign_key, foreign_key_value)
      association_name = foreign_key.sub(/_id\z/, "")

      association = record.class.reflect_on_association(association_name)
      return nil unless association

      if association.polymorphic?
        resolve_polymorphic_association(record, association_name, foreign_key_value)
      else
        resolve_regular_association(association, foreign_key_value)
      end
    end

    def resolve_polymorphic_association(record, association_name, foreign_key_value)
      type_column = "#{association_name}_type"
      type_value = record[type_column]
      return nil unless type_value

      model_class = type_value.constantize
      fixture_name = @record_lookup[model_class][foreign_key_value]
      return nil unless fixture_name

      {
        association_name => "#{fixture_name} (#{type_value})"
      }
    end

    def resolve_regular_association(association, foreign_key_value)
      target_class = association.klass
      fixture_name = @record_lookup[target_class][foreign_key_value]
      return nil unless fixture_name

      { association.name.to_s => fixture_name.to_s }
    end

    def serialize_value(value)
      case value
      when Time, DateTime
        value.iso8601
      when Date
        value.to_s
      when BigDecimal
        value.to_s("F")
      else
        value
      end
    end
  end
end
