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
      content = parse

      data = content.fetch("data").to_h do |coder_name, coder_data|
        coder = coder_for(coder_name)
        [coder.class, coder.decode(coder_data)]
      end

      exposed = content.fetch("exposed").each_with_object({}) do |(name, value), hash|
        if value.is_a?(Array)
          hash[name.to_sym] = value.map { |r| { ActiveSupport::Inflector.constantize(r.keys.first) => r.values.first } }
        else
          hash[name.to_sym] = { ActiveSupport::Inflector.constantize(value.keys.first) => value.values.first }
        end
      end

      MemoryCache.new(data: data, exposed: exposed)
    end

    def write(data)
      content = {
        data: data.data.to_h do |coder_class, coder_data|
          coder = coder_for(coder_class.name)
          [coder.class, coder.encode(coder_data)]
        end,
        exposed: data.exposed,
      }

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(content))
    end

    private

    # Reads and parses the cache file, validating that the required top-level
    # keys are present. The rescue is scoped to just this step so that decode
    # errors raised later in #read (e.g. an unregistered coder, a configuration
    # error) are not misreported as a corrupt cache file.
    def parse
      content = JSON.parse(File.read(path))
      content.fetch("data")
      content.fetch("exposed")
      content
    rescue JSON::ParserError, KeyError => e
      raise FixtureKit::CacheCorruptError.for(path, e)
    end

    def coder_for(class_name)
      @coder_for ||= FixtureKit.runner.coders.index_by { |c| c.class.name }
      @coder_for.fetch(class_name)
    end
  end
end
