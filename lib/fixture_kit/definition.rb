# frozen_string_literal: true

module FixtureKit
  class Definition
    ALLOWED_PRIMITIVE_CLASSES = [String, Integer, TrueClass, FalseClass, NilClass, Hash, Array].freeze

    attr_reader :exposed, :extends

    def initialize(extends: nil, &definition)
      @definition = definition
      @exposed = {}
      @extends = extends
    end

    def evaluate(context, parent: nil)
      context.singleton_class.prepend(mixin(parent))
      context.instance_exec(&@definition)
    end

    def expose(**records)
      records.each do |name, record|
        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, "Name #{name} already exposed"
        end

        validate_exposed_value!(name, record)
        @exposed[name] = record
      end
    end

    private

    def validate_exposed_value!(name, value)
      return if active_record?(value)

      if value.is_a?(Hash)
        validate_hash!(name, value)
        return
      end

      if value.is_a?(Array)
        value.each { |v| validate_exposed_value!(name, v) }
        return
      end

      return if allowed_primitive?(value)

      raise FixtureKit::UnsupportedExposedType,
        "Unsupported type #{value.class} for exposed name :#{name}. " \
        "Supported types: ActiveRecord::Base, String, Integer, TrueClass, FalseClass, NilClass, Hash, Array"
    end

    def validate_hash!(name, hash)
      hash.each do |key, value|
        unless allowed_primitive?(key)
          raise FixtureKit::UnsupportedExposedType,
            "Unsupported hash key type #{key.class} in exposed name :#{name}. " \
            "Hash keys must be one of: String, Integer, TrueClass, FalseClass, NilClass, Hash, Array"
        end

        validate_exposed_value!(name, value)
      end
    end

    def allowed_primitive?(value)
      ALLOWED_PRIMITIVE_CLASSES.any? { |klass| value.is_a?(klass) }
    end

    def active_record?(value)
      defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
    end

    def mixin(parent)
      definition = self

      Module.new do
        define_method(:expose) do |**records|
          definition.expose(**records)
        end

        define_method(:parent) do
          parent
        end
      end
    end
  end
end
