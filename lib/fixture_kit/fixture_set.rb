# frozen_string_literal: true

module FixtureKit
  class FixtureSet
    def initialize(exposed_records)
      @records = exposed_records
      @records.each_value { |value| value.freeze if value.is_a?(Array) }
      define_accessors
    end

    private

    def define_accessors
      @records.each do |name, value|
        define_singleton_method(name) { value }
      end
    end
  end
end
