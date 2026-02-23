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
    it "calls on_cache_save before saving when generating cache for the first time" do
      fixture = described_class.new(fixture_identifier, definition)
      callback = spy("on_cache_save")
      configuration.on_cache_save = callback

      expect(callback).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:save).ordered

      fixture.cache
    end

    it "does not call on_cache_save when cache already exists and force is false" do
      fixture = described_class.new(fixture_identifier, definition)
      callback = spy("on_cache_save")
      configuration.on_cache_save = callback
      allow(cache).to receive(:exists?).and_return(true)

      fixture.cache

      expect(cache).not_to have_received(:save)
      expect(callback).not_to have_received(:call)
    end

    it "calls on_cache_save during forced regeneration of existing cache" do
      fixture = described_class.new(fixture_identifier, definition)
      callback = spy("on_cache_save")
      configuration.on_cache_save = callback
      allow(cache).to receive(:exists?).and_return(true)

      expect(callback).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:save).ordered

      fixture.cache(force: true)
    end
  end

  describe "#mount" do
    it "calls on_cache_mount before loading cache" do
      fixture = described_class.new(fixture_identifier, definition)
      callback = spy("on_cache_mount")
      configuration.on_cache_mount = callback
      allow(cache).to receive(:exists?).and_return(true)

      expect(callback).to receive(:call).with(cache_identifier).ordered
      expect(cache).to receive(:load).ordered

      fixture.mount
    end

    it "does not call on_cache_mount when cache is missing" do
      fixture = described_class.new(fixture_identifier, definition)
      callback = spy("on_cache_mount")
      configuration.on_cache_mount = callback

      expect do
        fixture.mount
      end.to raise_error(FixtureKit::CacheMissingError, "Cache does not exist for fixture 'project management'")

      expect(callback).not_to have_received(:call)
    end
  end
end
