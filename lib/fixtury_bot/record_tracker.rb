# frozen_string_literal: true

module FixturyBot
  class RecordTracker
    RecordEntry = Struct.new(:record, :factory_name, :traits, :database_name, keyword_init: true) do
      attr_accessor :assigned_name

      def fixture_name
        assigned_name || auto_generated_name
      end

      def auto_generated_name
        nil
      end
    end

    attr_reader :records

    def initialize
      @records = []
      @name_to_record = {}
      @model_counters = Hash.new(0)
    end

    def track(record, factory_name: nil, traits: [])
      database_name = record.class.connection_db_config.name

      entry = RecordEntry.new(
        record: record,
        factory_name: factory_name,
        traits: traits,
        database_name: database_name
      )

      assign_auto_name(entry)

      @records << entry
      @name_to_record[entry.fixture_name] = entry.record if entry.fixture_name

      entry
    end

    def rename(record, new_name)
      new_name = new_name.to_sym
      entry = @records.find { |e| e.record.equal?(record) }
      raise ArgumentError, "Record not tracked" unless entry

      if @name_to_record.key?(new_name)
        raise FixturyBot::DuplicateNameError, <<~ERROR
          Duplicate fixture name :#{new_name}

          A record with this name already exists in this fixtury.
        ERROR
      end

      old_name = entry.fixture_name
      @name_to_record.delete(old_name)
      entry.assigned_name = new_name
      @name_to_record[new_name] = entry.record
    end

    def find_by_name(name)
      @name_to_record[name.to_sym]
    end

    def find_by_record(record)
      entry = @records.find { |e| e.record == record }
      entry&.fixture_name
    end

    def find_by_model_and_id(model_class, id)
      entry = @records.find { |e| e.record.class == model_class && e.record.id == id }
      entry&.fixture_name
    end

    def records_by_database
      @records.group_by(&:database_name)
    end

    def records_by_table(database_name = nil)
      records_to_group = database_name ? records_by_database[database_name] : @records
      return {} unless records_to_group

      records_to_group.group_by { |entry| entry.record.class.table_name }
    end

    private

    def assign_auto_name(entry)
      model_key = entry.record.class.name
      @model_counters[model_key] += 1
      counter = @model_counters[model_key]

      base_name = ActiveSupport::Inflector.underscore(entry.record.class.name).gsub("/", "_")
      entry.define_singleton_method(:auto_generated_name) { :"#{base_name}_#{counter}" }
    end
  end
end
