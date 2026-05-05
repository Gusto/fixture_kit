# frozen_string_literal: true

module FixtureKit
  class Coder
    def generate(parent_data: nil, &block)
      raise NotImplementedError, "#{self.class} must implement #generate"
    end

    def mount(data)
      raise NotImplementedError, "#{self.class} must implement #mount"
    end

    def encode(data)
      data
    end

    def decode(data)
      data
    end
  end
end
