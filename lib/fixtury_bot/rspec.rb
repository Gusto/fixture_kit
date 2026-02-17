# frozen_string_literal: true

module FixturyBot
  class FixturyAccessor
    def initialize(fixture_set)
      @fixture_set = fixture_set
    end

    def method_missing(name, *args, &block)
      if @fixture_set.key?(name.to_sym)
        @fixture_set[name.to_sym]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @fixture_set.key?(name.to_sym) || super
    end

    def [](name)
      @fixture_set[name.to_sym]
    end
  end

  module RSpec
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def fixtury(*fixtury_names)
        before(:each) do
          if FixturyBot.current_fixture_set.any?
            previously_loaded = FixturyBot.current_fixture_set.keys.first(3).join(", ")
            raise FixturyBot::DuplicateFixturyError, <<~ERROR
              fixtury called multiple times for the same example.

              Already loaded fixtures include: #{previously_loaded}...
              Attempting to load: #{fixtury_names.join(", ")}

              This usually means fixtury was called in both a parent and nested describe block.
              Only call fixtury once per example - use the most specific fixtury you need.
            ERROR
          end
          FixturyBot.load_definitions(*fixtury_names)
        end
      end
    end

    def fixtury
      FixturyAccessor.new(FixturyBot.current_fixture_set)
    end

    def fixtury_record(name)
      FixturyBot.current_fixture_set[name.to_sym]
    end
  end
end

RSpec.configure do |config|
  config.include FixturyBot::RSpec

  # Clear fixture set after each test to prevent state leakage
  config.after(:each) do
    FixturyBot.clear_current_fixture_set
  end
end if defined?(RSpec)
