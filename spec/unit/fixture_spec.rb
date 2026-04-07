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
      configuration.on_cache_save { |event| on_cache_save.call(event) }
      configuration.on_cache_saved { |event, duration| on_cache_saved.call(event, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.4
      end

      expect(on_cache_save).to receive(:call).with(an_instance_of(FixtureKit::Event)).ordered
      expect(cache).to receive(:save).ordered
      expect(on_cache_saved).to receive(:call).with(an_instance_of(FixtureKit::Event), be_within(0.001).of(0.4)).ordered

      fixture.generate
    end

    it "provides identifier and path on the event" do
      fixture = described_class.new(fixture_identifier, definition)
      received_event = nil
      configuration.on_cache_save { |event| received_event = event }

      fixture.generate

      expect(received_event.identifier).to eq(cache_identifier)
      expect(received_event.path).to eq(definition.source_location)
    end

    it "does not call save callbacks when cache already exists and force is false" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_save = spy("on_cache_save")
      on_cache_saved = spy("on_cache_saved")
      configuration.on_cache_save { |event| on_cache_save.call(event) }
      configuration.on_cache_saved { |event, duration| on_cache_saved.call(event, duration) }
      allow(cache).to receive(:exists?).and_return(true)

      fixture.generate

      expect(cache).not_to have_received(:save)
      expect(on_cache_save).not_to have_received(:call)
      expect(on_cache_saved).not_to have_received(:call)
    end

    it "calls save callbacks during forced regeneration of existing cache" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_save = spy("on_cache_save")
      on_cache_saved = spy("on_cache_saved")
      configuration.on_cache_save { |event| on_cache_save.call(event) }
      configuration.on_cache_saved { |event, duration| on_cache_saved.call(event, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.25
      end
      allow(cache).to receive(:exists?).and_return(true)

      expect(on_cache_save).to receive(:call).with(an_instance_of(FixtureKit::Event)).ordered
      expect(cache).to receive(:save).ordered
      expect(on_cache_saved).to receive(:call).with(an_instance_of(FixtureKit::Event), be_within(0.001).of(0.25)).ordered

      fixture.generate(force: true)
    end

    it "caches parent fixture before child fixture" do
      parent_fixture = instance_double(FixtureKit::Fixture, generate: nil)
      allow(cache).to receive(:exists?).and_return(false)
      inherited_definition = FixtureKit::Definition.new(extends: "teams/basic") {}
      allow(runner.registry).to receive(:add).with("teams/basic").and_return(parent_fixture)
      inherited_fixture = described_class.new(fixture_identifier, inherited_definition)

      expect(parent_fixture).to receive(:generate).with(no_args).ordered
      expect(cache).to receive(:save).ordered

      inherited_fixture.generate
    end

  end

  describe "#mount" do
    it "calls mount callbacks around cache loading" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_mount = spy("on_cache_mount")
      on_cache_mounted = spy("on_cache_mounted")
      configuration.on_cache_mount { |event| on_cache_mount.call(event) }
      configuration.on_cache_mounted { |event, duration| on_cache_mounted.call(event, duration) }
      allow(Benchmark).to receive(:realtime) do |&block|
        block.call
        0.3
      end
      allow(cache).to receive(:exists?).and_return(true)

      expect(on_cache_mount).to receive(:call).with(an_instance_of(FixtureKit::Event)).ordered
      expect(cache).to receive(:load).ordered
      expect(on_cache_mounted).to receive(:call).with(an_instance_of(FixtureKit::Event), be_within(0.001).of(0.3)).ordered

      fixture.mount
    end

    it "does not call mount callbacks when cache is missing" do
      fixture = described_class.new(fixture_identifier, definition)
      on_cache_mount = spy("on_cache_mount")
      on_cache_mounted = spy("on_cache_mounted")
      configuration.on_cache_mount { |event| on_cache_mount.call(event) }
      configuration.on_cache_mounted { |event, duration| on_cache_mounted.call(event, duration) }

      expect do
        fixture.mount
      end.to raise_error(FixtureKit::CacheMissingError, "Cache does not exist for fixture 'project management'")

      expect(on_cache_mount).not_to have_received(:call)
      expect(on_cache_mounted).not_to have_received(:call)
    end
  end

  describe "#finish" do
    it "clears memory for anonymous fixtures" do
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_scope = Class.new
      allow(cache).to receive(:clear_memory)
      fixture = described_class.new(anonymous_scope, anonymous_definition)

      fixture.finish

      expect(cache).to have_received(:clear_memory)
    end

    it "does not clear memory for named fixtures" do
      allow(cache).to receive(:clear_memory)
      fixture = described_class.new("project_management", definition)

      fixture.finish

      expect(cache).not_to have_received(:clear_memory)
    end

    it "allows a finished anonymous fixture to still be mounted from file cache" do
      allow(cache).to receive(:clear_memory)
      allow(cache).to receive(:exists?).and_return(true)
      anonymous_definition = FixtureKit::Definition.new {}
      anonymous_scope = Class.new
      fixture = described_class.new(anonymous_scope, anonymous_definition)

      fixture.finish
      result = fixture.mount

      expect(cache).to have_received(:clear_memory)
      expect(result).to eq(:repository)
    end
  end

  describe "#parent" do
    it "loads and memoizes parent fixture from registry" do
      parent_fixture = instance_double(FixtureKit::Fixture)
      definition = FixtureKit::Definition.new(extends: "teams/basic") {}
      allow(runner.registry).to receive(:add).with("teams/basic").and_return(parent_fixture)
      fixture = described_class.new(fixture_identifier, definition)

      expect(fixture.parent).to equal(parent_fixture)
      expect(fixture.parent).to equal(parent_fixture)
      expect(runner.registry).to have_received(:add).with("teams/basic").once
    end
  end
end
