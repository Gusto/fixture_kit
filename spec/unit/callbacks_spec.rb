# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Callbacks do
  describe "#register" do
    it "returns an empty list when no callback is provided" do
      expect(described_class.new.register(:cache_save)).to eq([])
    end

    it "appends callbacks and returns them in registration order" do
      callbacks = described_class.new
      callback_one = proc {}
      callback_two = proc {}

      callbacks.register(:cache_save, &callback_one)
      expect(callbacks.register(:cache_save, &callback_two)).to eq([callback_one, callback_two])
    end

    it "raises for unknown callback keys" do
      expect do
        described_class.new.register(:unknown_callback)
      end.to raise_error(ArgumentError, "Unknown callback event: unknown_callback")
    end
  end

  describe "#run" do
    it "runs callbacks in registration order with args" do
      callbacks = described_class.new
      callback_one = spy("callback_one")
      callback_two = spy("callback_two")
      callbacks.register(:cache_saved) { |identifier, duration| callback_one.call(identifier, duration) }
      callbacks.register(:cache_saved) { |identifier, duration| callback_two.call(identifier, duration) }

      expect(callback_one).to receive(:call).with("teams/basic", 0.2).ordered
      expect(callback_two).to receive(:call).with("teams/basic", 0.2).ordered

      callbacks.run(:cache_saved, "teams/basic", 0.2)
    end

    it "does nothing when there are no callbacks for a known key" do
      expect do
        described_class.new.run(:cache_mount, "teams/basic")
      end.not_to raise_error
    end

    it "raises for unknown callback keys" do
      expect do
        described_class.new.run(:unknown_callback)
      end.to raise_error(ArgumentError, "Unknown callback event: unknown_callback")
    end
  end
end
