# frozen_string_literal: true

module FixtureKit
  class Coder
    def observe(&block)
      yield
    end

    def save(parent_data: nil)
      raise NotImplementedError, "#{self.class} must implement #save"
    end

    def mount(data)
      raise NotImplementedError, "#{self.class} must implement #mount"
    end
  end
end
