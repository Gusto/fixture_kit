# frozen_string_literal: true

module FixtureKit
  module Singleton
    def configure
      yield(runner.configuration) if block_given?
      self
    end

    def runner
      @runner ||= Runner.new
    end

    def define(&block)
      Definition.new(&block)
    end

    def reset
      @runner = nil
    end
  end
end
