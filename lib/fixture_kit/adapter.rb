# frozen_string_literal: true

module FixtureKit
  class Adapter
    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    def execute
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    def identifier_for(_identifier)
      raise NotImplementedError, "#{self.class} must implement #identifier_for"
    end
  end
end
