# frozen_string_literal: true

module FixtureKit
  # Base class for fixture cache generators.
  class Generator
    def self.run(&block)
      new.run(&block)
    end

    def run
      raise NotImplementedError, "#{self.class} must implement #run"
    end
  end
end
