# frozen_string_literal: true

module FixtureKit
  class FixtureSet
    def initialize(exposed_records)
      @records = exposed_records
      define_accessors
    end

    def [](name)
      @records[name.to_sym]
    end

    def to_h
      @records.dup
    end

    private

    def define_accessors
      @records.each do |name, value|
        define_singleton_method(name) { value }
      end
    end
  end
end
