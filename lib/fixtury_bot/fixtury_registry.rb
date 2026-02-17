# frozen_string_literal: true

module FixturyBot
  module FixturyRegistry
    class << self
      def register(fixtury)
        fixturys[fixtury.name] = fixtury
      end

      def find(name)
        fixturys[name.to_sym]
      end

      def fixtury_names
        fixturys.keys
      end

      def reset
        @fixturys = nil
      end

      private

      def fixturys
        @fixturys ||= {}
      end
    end
  end
end
