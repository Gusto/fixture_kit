# frozen_string_literal: true

module FixtureKit
  class Configuration
    attr_writer :fixture_path
    attr_writer :cache_path
    attr_accessor :autogenerate

    def initialize
      @fixture_path = nil
      @cache_path = nil
      @autogenerate = true
    end

    def fixture_path
      @fixture_path ||= detect_fixture_path
    end

    def cache_path
      @cache_path ||= detect_cache_path
    end

    private

    def detect_fixture_path
      if defined?(RSpec)
        "spec/fixture_kit"
      elsif defined?(Minitest)
        "test/fixture_kit"
      elsif Dir.exist?("spec")
        "spec/fixture_kit"
      elsif Dir.exist?("test")
        "test/fixture_kit"
      else
        "spec/fixture_kit"
      end
    end

    def detect_cache_path
      "tmp/cache/fixture_kit"
    end
  end
end
