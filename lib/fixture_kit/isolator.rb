# frozen_string_literal: true

module FixtureKit
  # Base class for fixture cache isolators.
  class Isolator
    def self.run(&block)
      new.run(&block)
    end

    def run
      raise NotImplementedError, "#{self.class} must implement #run"
    end
  end
end
