# frozen_string_literal: true

module FixtureKit
  class Callbacks
    EVENTS = [
      :register,
      :cache_save,
      :cache_saved,
      :cache_mount,
      :cache_mounted
    ].freeze

    def initialize
      @callbacks = Hash.new { |hash, key| hash[key] = [] }
    end

    def register(event, &block)
      validate_event!(event)
      @callbacks[event] << block if block
      @callbacks[event]
    end

    def run(event, *args)
      validate_event!(event)
      @callbacks[event].each do |callback|
        callback.call(*args)
      end
    end

    private

    def validate_event!(event)
      unless EVENTS.include?(event)
        raise ArgumentError, "Unknown callback event: #{event}"
      end
    end
  end
end
