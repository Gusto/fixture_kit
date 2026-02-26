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

      exposed = file_data.fetch("exposed").each_with_object({}) do |(name, value), hash|
        if value.is_a?(Array)
          hash[name.to_sym] = value.map { |r| { ActiveSupport::Inflector.constantize(r.keys.first) => r.values.first } }
        else
          hash[name.to_sym] = { ActiveSupport::Inflector.constantize(value.keys.first) => value.values.first }
        end
      end

      MemoryCache.new(records: records, exposed: exposed)
    end

    def write(data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(data.to_h))
    end

    def serialize_exposed(exposed)
      exposed.each_with_object({}) do |(name, record), hash|
        if record.is_a?(Array)
          hash[name] = record.map { |record| { record.class => record.id } }
        else
          hash[name] = { record.class => record.id }
        end
      end
    end
  end
end
