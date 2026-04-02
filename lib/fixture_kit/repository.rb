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
      resolve(value)
    end

    def resolve(value)
      if value.is_a?(Hash) && value.key?("_model")
        load_record(ActiveSupport::Inflector.constantize(value["_model"]), value["_id"])
      elsif value.is_a?(Hash)
        value.transform_values { |v| resolve(v) }.freeze
      elsif value.is_a?(Array)
        value.map { |v| resolve(v) }.freeze
      else
        value
      end
    end

    def load_record(model, id)
      model.unscoped.find_by(id: id)
    end
  end
end
