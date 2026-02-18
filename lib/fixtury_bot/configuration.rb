# frozen_string_literal: true

module FixturyBot
  class Configuration
    attr_writer :fixtury_path
    attr_writer :cache_path
    attr_accessor :output

    def initialize
      @fixtury_path = nil
      @cache_path = nil
      @setup = nil
      @output = $stdout
    end

    # Set a block to run before each fixtury is executed.
    # Useful for setting a fixed seed for Faker/FFaker.
    #
    # Example:
    #   FixturyBot.configure do |config|
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

    def fixtury_path
      @fixtury_path ||= detect_fixtury_path
    end

    def cache_path
      @cache_path ||= detect_cache_path
    end

    private

    def detect_fixtury_path
      if Dir.exist?("spec")
        "spec/fixtury"
      elsif Dir.exist?("test")
        "test/fixtury"
      else
        "spec/fixtury"
      end
    end

    def detect_cache_path
      "tmp/fixtury_cache"
    end
  end
end
