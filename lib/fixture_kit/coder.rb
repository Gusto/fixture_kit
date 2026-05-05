# frozen_string_literal: true

module FixtureKit
  class Coder
    def save(parent_data: nil, &block)
      raise NotImplementedError, "#{self.class} must implement #save"
    end

    def load(data)
      raise NotImplementedError, "#{self.class} must implement #load"
    end
  end
end
