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

      data = file_data.fetch("data").each_with_object({}) do |(coder_name, coder_data), hash|
        coder_class = ActiveSupport::Inflector.constantize(coder_name)
        hash[coder_class] = coder_class.new.decode(coder_data)
      end

      exposed = file_data.fetch("exposed").each_with_object({}) do |(name, value), hash|
        if value.is_a?(Array)
          hash[name.to_sym] = value.map { |r| { ActiveSupport::Inflector.constantize(r.keys.first) => r.values.first } }
        else
          hash[name.to_sym] = { ActiveSupport::Inflector.constantize(value.keys.first) => value.values.first }
        end
      end

      MemoryCache.new(data: data, exposed: exposed)
    end

    def write(data)
      file_data = {
        data: data.data.to_h do |coder_class, coder_data|
          [coder_class, coder_class.new.encode(coder_data)]
        end,
        exposed: data.exposed,
      }

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(file_data))
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
