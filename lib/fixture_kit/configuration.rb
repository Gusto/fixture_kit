# frozen_string_literal: true

module FixtureKit
  class Configuration
    attr_writer :fixture_path
    attr_writer :cache_path
    attr_accessor :isolator
    attr_accessor :on_cache_save
    attr_accessor :on_cache_mount

    def initialize
      @fixture_path = "fixture_kit"
      @cache_path = nil
      @isolator = FixtureKit::MinitestIsolator
      @on_cache_save = nil
      @on_cache_mount = nil
    end

    def fixture_path
      @fixture_path
    end

    def cache_path
      @cache_path ||= detect_cache_path
    end

    private

    def detect_cache_path
      "tmp/cache/fixture_kit"
    end
  end
end
