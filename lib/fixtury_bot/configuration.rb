# frozen_string_literal: true

module FixturyBot
  class Configuration
    attr_writer :fixtury_path
    attr_writer :fixtures_path
    attr_accessor :output
    attr_accessor :autogenerate

    def initialize
      @fixtury_path = nil
      @fixtures_path = nil
      @setup = nil
      @output = $stdout
      @autogenerate = true
    end

    # Set a block to run before each fixtury is dumped.
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

    def fixtures_path
      @fixtures_path ||= detect_fixtures_path
    end

    def fixtury_path
      @fixtury_path ||= detect_fixtury_path
    end

    private

    def detect_fixtures_path
      if Dir.exist?("spec")
        "spec/fixtures/fixtury_bot"
      elsif Dir.exist?("test")
        "test/fixtures/fixtury_bot"
      else
        "spec/fixtures/fixtury_bot"
      end
    end

    def detect_fixtury_path
      if Dir.exist?("spec")
        "spec/fixtury"
      elsif Dir.exist?("test")
        "test/fixtury"
      else
        "spec/fixtury"
      end
    end
  end
end
