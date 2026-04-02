# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/inflector"

module FixtureKit
  class FileCache
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def exists?
      File.exist?(path)
    end

    def read
      file_data = JSON.parse(File.read(path))
      records = file_data.fetch("records").transform_keys do |model_name|
        ActiveSupport::Inflector.constantize(model_name)
      end

      exposed = file_data.fetch("exposed").transform_keys(&:to_sym)

      MemoryCache.new(records: records, exposed: exposed)
    end

    def write(data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(data.to_h))
    end

    def serialize_exposed(exposed)
      exposed.each_with_object({}) do |(name, value), hash|
        hash[name] = serialize_value(value)
      end
    end

    private

    def active_record?(value)
      defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
    end

    def serialize_value(value)
      if active_record?(value)
        { "_model" => value.class.name, "_id" => value.id }
      elsif value.is_a?(Hash)
        value.transform_values { |v| serialize_value(v) }
      elsif value.is_a?(Array)
        value.map { |v| serialize_value(v) }
      else
        value
      end
    end

  end
end
