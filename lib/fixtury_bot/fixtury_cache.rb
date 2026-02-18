# frozen_string_literal: true

require "yaml"
require "fileutils"

module FixturyBot
  class FixturyCache
    attr_reader :records, :exposed

    def initialize(fixtury_name, cache_path)
      @fixtury_name = fixtury_name
      @cache_path = cache_path
      @records = {}
      @exposed = {}
    end

    def cache_file_path
      File.join(@cache_path, "#{@fixtury_name}.yml")
    end

    def exists?
      File.exist?(cache_file_path)
    end

    def load
      return false unless exists?

      # Using unsafe_load since this is a cache file we generate ourselves
      data = YAML.unsafe_load_file(cache_file_path)
      @records = data["records"] || {}
      @exposed = data["exposed"] || {}
      true
    end

    def save(records_by_model, exposed_mapping)
      @records = records_by_model
      @exposed = exposed_mapping

      FileUtils.mkdir_p(@cache_path)

      data = {
        "records" => @records,
        "exposed" => @exposed
      }

      File.write(cache_file_path, data.to_yaml)
    end
  end
end
