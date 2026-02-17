# frozen_string_literal: true

require "yaml"
require "active_record/fixtures"

module FixturyBot
  class FixtureLoader
    def initialize(fixtury_name, fixtures_path)
      @fixtury_name = fixtury_name
      @fixtures_path = fixtures_path
    end

    def load
      fixtury_path = File.join(@fixtures_path, @fixtury_name.to_s)

      unless Dir.exist?(fixtury_path)
        raise ArgumentError, "Fixtury fixtures not found at #{fixtury_path}. Run 'fixtury_bot generate #{@fixtury_name}' first."
      end

      # Clear ActiveRecord fixture cache to ensure fresh fixture data
      ActiveRecord::FixtureSet.reset_cache

      raw_metadata = load_metadata(fixtury_path)
      databases = raw_metadata.is_a?(Hash) && raw_metadata.key?("databases") ? raw_metadata["databases"] : raw_metadata
      exposed_metadata = raw_metadata.is_a?(Hash) ? raw_metadata["exposed"] : nil

      all_records = {}

      databases.each do |database_name, model_class_name|
        database_path = File.join(fixtury_path, database_name)
        next unless Dir.exist?(database_path)

        model_class = model_class_name.constantize
        fixture_files = Dir.glob(File.join(database_path, "*.yml")).map do |f|
          File.basename(f, ".yml")
        end

        next if fixture_files.empty?

        class_names = build_class_names(database_path, fixture_files)

        fixtures = ActiveRecord::FixtureSet.create_fixtures(
          database_path,
          fixture_files,
          class_names,
          model_class
        )

        # Look up actual records from the database using fixture identifiers
        fixtures.each do |fixture_set|
          model = class_names[fixture_set.table_name]
          next unless model

          fixture_set.each do |fixture_name, _fixture|
            # ActiveRecord::FixtureSet generates consistent IDs based on fixture name
            record_id = ActiveRecord::FixtureSet.identify(fixture_name)
            record = model.find_by(id: record_id)
            all_records[fixture_name.to_sym] = record if record
          end
        end
      end

      build_exposed_result(all_records, exposed_metadata)
    end

    private

    def build_exposed_result(all_records, exposed_metadata)
      return all_records unless exposed_metadata

      result = {}

      exposed_metadata.each do |name, value|
        name = name.to_sym

        if value.is_a?(Array)
          result[name] = value.filter_map { |fixture_name| all_records[fixture_name.to_sym] }
        else
          result[name] = all_records[value.to_sym]
        end
      end

      result
    end

    def load_metadata(fixtury_path)
      metadata_path = File.join(fixtury_path, ".fixtury_bot.yml")

      unless File.exist?(metadata_path)
        raise ArgumentError, "Metadata file not found at #{metadata_path}"
      end

      YAML.load_file(metadata_path, permitted_classes: [Symbol])
    end

    def build_class_names(database_path, fixture_files)
      class_names = {}

      fixture_files.each do |table_name|
        file_path = File.join(database_path, "#{table_name}.yml")
        fixture_data = YAML.load_file(file_path, permitted_classes: [Symbol])

        next if fixture_data.nil? || fixture_data.empty?

        model_class = infer_model_class(table_name)
        class_names[table_name] = model_class if model_class
      end

      class_names
    end

    def infer_model_class(table_name)
      table_name.classify.constantize
    rescue NameError
      nil
    end
  end
end
