# frozen_string_literal: true

require "yaml"

module FixturyBot
  class Validator
    ValidationResult = Struct.new(:valid?, :differences, keyword_init: true)

    def initialize(fixtury_name = nil)
      @fixtury_name = fixtury_name
    end

    def validate
      fixtury_names = @fixtury_name ? [@fixtury_name.to_sym] : FixturyRegistry.fixtury_names

      all_valid = true
      all_differences = {}

      fixtury_names.each do |name|
        result = validate_fixtury(name)
        unless result.valid?
          all_valid = false
          all_differences[name] = result.differences
        end
      end

      ValidationResult.new(valid?: all_valid, differences: all_differences)
    end

    private

    def validate_fixtury(name)
      fixtury = FixturyRegistry.find(name)
      raise ArgumentError, "Fixtury '#{name}' not found" unless fixtury

      fixtures_path = FixturyBot.configuration.fixtures_path
      fixtury_path = File.join(fixtures_path, name.to_s)

      unless Dir.exist?(fixtury_path)
        return ValidationResult.new(
          valid?: false,
          differences: { error: "Fixture directory not found at #{fixtury_path}" }
        )
      end

      result = fixtury.execute
      generated_fixtures = generate_in_memory_fixtures(result.records)
      committed_fixtures = load_committed_fixtures(fixtury_path)

      differences = compare_fixtures(generated_fixtures, committed_fixtures)

      ValidationResult.new(valid?: differences.empty?, differences: differences)
    end

    def generate_in_memory_fixtures(records)
      fixtures = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

      record_lookup = build_record_lookup(records)

      records.each do |entry|
        database_name = entry.database_name
        table_name = entry.record.class.table_name
        fixture_name = entry.fixture_name.to_s

        fixtures[database_name][table_name][fixture_name] = serialize_record(entry.record, record_lookup)
      end

      fixtures
    end

    def build_record_lookup(records)
      lookup = Hash.new { |h, k| h[k] = {} }

      records.each do |entry|
        model_class = entry.record.class
        lookup[model_class][entry.record.id] = entry.fixture_name
      end

      lookup
    end

    def serialize_record(record, record_lookup)
      excluded_columns = %w[id created_at updated_at created_on updated_on]
      attributes = record.attributes.except(*excluded_columns)
      serialized = {}

      # Pre-calculate which polymorphic type columns should be skipped
      polymorphic_type_columns = find_resolvable_polymorphic_types(record, attributes, record_lookup)

      attributes.each do |key, value|
        next if value.nil?
        next if polymorphic_type_columns.include?(key)

        if key.end_with?("_id")
          resolved = resolve_association(record, key, value, record_lookup)
          if resolved
            serialized.merge!(resolved)
            next
          end
        end

        serialized[key] = serialize_value(value)
      end

      serialized
    end

    def find_resolvable_polymorphic_types(record, attributes, record_lookup)
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
        fixture_name = record_lookup[model_class][value]
        type_columns << type_column if fixture_name
      end

      type_columns
    end

    def resolve_association(record, foreign_key, foreign_key_value, record_lookup)
      association_name = foreign_key.sub(/_id\z/, "")
      association = record.class.reflect_on_association(association_name)
      return nil unless association

      if association.polymorphic?
        type_column = "#{association_name}_type"
        type_value = record[type_column]
        return nil unless type_value

        model_class = type_value.constantize
        fixture_name = record_lookup[model_class][foreign_key_value]
        return nil unless fixture_name

        { association_name => "#{fixture_name} (#{type_value})" }
      else
        target_class = association.klass
        fixture_name = record_lookup[target_class][foreign_key_value]
        return nil unless fixture_name

        { association.name.to_s => fixture_name.to_s }
      end
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

    def load_committed_fixtures(fixtury_path)
      fixtures = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

      Dir.glob(File.join(fixtury_path, "*")).each do |database_path|
        next unless File.directory?(database_path)
        next if File.basename(database_path).start_with?(".")

        database_name = File.basename(database_path)

        Dir.glob(File.join(database_path, "*.yml")).each do |file_path|
          table_name = File.basename(file_path, ".yml")
          fixture_data = YAML.load_file(file_path, permitted_classes: [Symbol]) || {}
          fixtures[database_name][table_name] = fixture_data
        end
      end

      fixtures
    end

    def compare_fixtures(generated, committed)
      differences = []

      all_databases = (generated.keys + committed.keys).uniq

      all_databases.each do |database_name|
        gen_tables = generated[database_name] || {}
        com_tables = committed[database_name] || {}

        all_tables = (gen_tables.keys + com_tables.keys).uniq

        all_tables.each do |table_name|
          gen_fixtures = gen_tables[table_name] || {}
          com_fixtures = com_tables[table_name] || {}

          gen_fixtures.each do |fixture_name, gen_attrs|
            if com_fixtures.key?(fixture_name)
              com_attrs = com_fixtures[fixture_name]
              attr_diff = compare_attributes(gen_attrs, com_attrs)
              unless attr_diff.empty?
                differences << {
                  type: :modified,
                  database: database_name,
                  table: table_name,
                  fixture: fixture_name,
                  changes: attr_diff
                }
              end
            else
              differences << {
                type: :new,
                database: database_name,
                table: table_name,
                fixture: fixture_name,
                attributes: gen_attrs
              }
            end
          end

          com_fixtures.each_key do |fixture_name|
            unless gen_fixtures.key?(fixture_name)
              differences << {
                type: :removed,
                database: database_name,
                table: table_name,
                fixture: fixture_name
              }
            end
          end
        end
      end

      differences
    end

    def compare_attributes(gen_attrs, com_attrs)
      changes = {}

      all_keys = (gen_attrs.keys + com_attrs.keys).uniq

      all_keys.each do |key|
        gen_val = normalize_value(gen_attrs[key])
        com_val = normalize_value(com_attrs[key])

        if gen_val != com_val
          changes[key] = { generated: gen_val, committed: com_val }
        end
      end

      changes
    end

    def normalize_value(value)
      case value
      when String
        value.strip
      else
        value
      end
    end
  end
end
