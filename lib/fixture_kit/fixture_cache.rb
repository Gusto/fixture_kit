# frozen_string_literal: true

require "json"
require "fileutils"
require "digest"

module FixtureKit
  class FixtureCache
    # In-memory cache to avoid re-reading/parsing JSON for every test
    @memory_cache = {}

    class << self
      attr_accessor :memory_cache

      def clear_memory_cache(fixture_name = nil)
        if fixture_name
          @memory_cache.delete(fixture_name.to_s)
        else
          @memory_cache.clear
        end
      end

      def in_memory?(fixture_name)
        @memory_cache.key?(fixture_name.to_s)
      end
    end

    attr_reader :records, :exposed, :digest

    def initialize(fixture_name, cache_path)
      @fixture_name = fixture_name.to_s
      @cache_path = cache_path
      @records = {}
      @exposed = {}
      @digest = nil
    end

    def cache_file_path
      File.join(@cache_path, "#{@fixture_name}.json")
    end

    def exists?
      # Check in-memory cache first, then disk
      self.class.memory_cache.key?(@fixture_name) || File.exist?(cache_file_path)
    end

    def load
      # Check in-memory cache first
      if self.class.memory_cache.key?(@fixture_name)
        data = self.class.memory_cache[@fixture_name]
        @records = data["records"] || {}
        @exposed = data["exposed"] || {}
        @digest = data["digest"]
        return true
      end

      # Fall back to disk
      return false unless File.exist?(cache_file_path)

      data = JSON.parse(File.read(cache_file_path))
      @records = data["records"] || {}
      @exposed = data["exposed"] || {}
      @digest = data["digest"]

      # Store in memory for subsequent loads
      self.class.memory_cache[@fixture_name] = data

      true
    end

    def save(records_by_model, exposed_mapping, digest: nil)
      @records = records_by_model
      @exposed = exposed_mapping
      @digest = digest

      FileUtils.mkdir_p(File.dirname(cache_file_path))

      data = {
        "digest" => @digest,
        "records" => @records,
        "exposed" => @exposed
      }

      # Store in memory cache
      self.class.memory_cache[@fixture_name] = data

      File.write(cache_file_path, JSON.pretty_generate(data))
    end

    # Compute digest of a file's contents
    def self.compute_digest(file_path)
      return nil unless file_path && File.exist?(file_path)

      Digest::MD5.hexdigest(File.read(file_path))
    end
  end
end
