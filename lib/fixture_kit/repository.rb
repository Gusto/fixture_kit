# frozen_string_literal: true

require "active_support/inflector"

module FixtureKit
  class Repository
    def initialize(exposed_records)
      @records = exposed_records
      @loaded_records = {}
      define_readers
    end

    private

    def define_readers
      @records.each_key do |name|
        define_singleton_method(name) { fetch(name) }
      end
    end

    def fetch(name)
      return @loaded_records[name] if @loaded_records.key?(name)

      @loaded_records[name] = materialize(@records.fetch(name))
    end

    def materialize(value)
      if value.is_a?(Array)
        value.map { |record_info| load_record(record_info) }.freeze
      else
        load_record(value)
      end
    end

    def load_record(record_info)
      record_info.keys.first.unscoped.find_by(id: record_info.values.first)
    end
  end
end
