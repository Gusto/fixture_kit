# frozen_string_literal: true

module FixtureKit
  class Configuration
    attr_writer :fixture_path
    attr_writer :cache_path

    def initialize
      @fixture_path = nil
      @cache_path = nil
      @setup = nil
    end

    # Set a block to run before each fixture is executed.
    # Useful for setting a fixed seed for Faker/FFaker.
    #
    # Example:
    #   FixtureKit.configure do |config|
    #     config.setup do
    #       FFaker::Random.seed = 12345
    #       Faker::Config.random = Random.new(12345)
    #     end
    #   end
    def setup(&block)
      if block_given?
        @setup = block
      else
        @setup
      end
    end

    def fixture_path
      @fixture_path ||= detect_fixture_path
    end

    def cache_path
      @cache_path ||= detect_cache_path
    end

    private

    def detect_fixture_path
      if Dir.exist?("spec")
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
