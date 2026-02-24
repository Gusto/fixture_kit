# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Fixture do
  let(:fixture_identifier) { "project management" }
  let(:cache_identifier) { "project_management" }
  let(:cache_exists) { false }
  let(:cache) do
    instance_double(
      FixtureKit::Cache,
      identifier: cache_identifier,
      exists?: cache_exists,
      save: nil,
      load: :repository
    )
  end
  let(:runner) { FixtureKit::Runner.new }
  let(:configuration) { runner.configuration }
  let(:definition) { FixtureKit.define {} }

  before do
    allow(FixtureKit::Cache).to receive(:new).and_return(cache)
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  describe "#cache" do
    it "calls save callbacks around cache generation" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_save = spy("on_cache_save")
      on_cache_saved = spy("on_cache_saved")
      configuration.on_cache_save { |identifier| on_cache_save.call(identifier) }
      configuration.on_cache_saved { |identifier, duration| on_cache_saved.call(identifier, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.4
      end

      expect(on_cache_save).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:save).ordered
      expect(on_cache_saved).to receive(:call).with(cache_identifier, be_within(0.001).of(0.4)).ordered

      fixture.cache
    end

    it "does not call save callbacks when cache already exists and force is false" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_save = spy("on_cache_save")
      on_cache_saved = spy("on_cache_saved")
      configuration.on_cache_save { |identifier| on_cache_save.call(identifier) }
      configuration.on_cache_saved { |identifier, duration| on_cache_saved.call(identifier, duration) }
      allow(cache).to receive(:exists?).and_return(true)

      fixture.cache

      expect(cache).not_to have_received(:save)
      expect(on_cache_save).not_to have_received(:call)
      expect(on_cache_saved).not_to have_received(:call)
    end

    it "calls save callbacks during forced regeneration of existing cache" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_save = spy("on_cache_save")
      on_cache_saved = spy("on_cache_saved")
      configuration.on_cache_save { |identifier| on_cache_save.call(identifier) }
      configuration.on_cache_saved { |identifier, duration| on_cache_saved.call(identifier, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.25
      end
      allow(cache).to receive(:exists?).and_return(true)

      expect(on_cache_save).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:save).ordered
      expect(on_cache_saved).to receive(:call).with(cache_identifier, be_within(0.001).of(0.25)).ordered

      fixture.cache(force: true)
    end
  end

  describe "#mount" do
    it "calls mount callbacks around cache loading" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_mount = spy("on_cache_mount")
      on_cache_mounted = spy("on_cache_mounted")
      configuration.on_cache_mount { |identifier| on_cache_mount.call(identifier) }
      configuration.on_cache_mounted { |identifier, duration| on_cache_mounted.call(identifier, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.3
      end
      allow(cache).to receive(:exists?).and_return(true)

      expect(on_cache_mount).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:load).ordered
      expect(on_cache_mounted).to receive(:call).with(cache_identifier, be_within(0.001).of(0.3)).ordered

      fixture.mount
    end

    it "does not call mount callbacks when cache is missing" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_mount = spy("on_cache_mount")
      on_cache_mounted = spy("on_cache_mounted")
      configuration.on_cache_mount { |identifier| on_cache_mount.call(identifier) }
      configuration.on_cache_mounted { |identifier, duration| on_cache_mounted.call(identifier, duration) }

      expect do
        fixture.mount
      end.to raise_error(FixtureKit::CacheMissingError, "Cache does not exist for fixture 'project management'")

      expect(on_cache_mount).not_to have_received(:call)
      expect(on_cache_mounted).not_to have_received(:call)
    end
  end
end
