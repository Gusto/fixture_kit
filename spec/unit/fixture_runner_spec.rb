# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Runner do
  let(:scope) { Class.new }
  let(:fixture_name) { "project_management" }
  let(:fixture) { instance_double(FixtureKit::Fixture, identifier: fixture_name, generate: nil) }
  let(:registry) { instance_double(FixtureKit::Registry, fixtures: [fixture]) }

  before do
    allow(FixtureKit::Registry).to receive(:new).and_return(registry)
    allow(registry).to receive(:add).and_return(fixture)
  end

  describe "#adapter" do
    it "instantiates the configured adapter once and memoizes it" do
      runner = described_class.new
      adapter_instance = instance_double(FixtureKit::MinitestAdapter)
      adapter_class = class_double(FixtureKit::MinitestAdapter, new: adapter_instance)
      runner.configuration.adapter(adapter_class, option1: "value1")

      first_adapter = runner.adapter
      second_adapter = runner.adapter

      expect(first_adapter).to equal(adapter_instance)
      expect(second_adapter).to equal(adapter_instance)
      expect(adapter_class).to have_received(:new).with(option1: "value1").once
    end
  end

  describe "#start" do
    it "clears all cache files at startup" do
      runner = described_class.new
      allow(FileUtils).to receive(:rm_rf)

      runner.start

      expect(FileUtils).to have_received(:rm_rf).with(runner.configuration.cache_path)
    end

    it "does not clear cache when FIXTURE_KIT_PRESERVE_CACHE is truthy" do
      runner = described_class.new
      allow(FileUtils).to receive(:rm_rf)
      ENV[FixtureKit::Runner::PRESERVE_CACHE_ENV_KEY] = "1"

      runner.start

      expect(FileUtils).not_to have_received(:rm_rf)
    ensure
      ENV.delete(FixtureKit::Runner::PRESERVE_CACHE_ENV_KEY)
    end

    it "clears cache when FIXTURE_KIT_PRESERVE_CACHE is falsey" do
      runner = described_class.new
      allow(FileUtils).to receive(:rm_rf)
      ENV[FixtureKit::Runner::PRESERVE_CACHE_ENV_KEY] = "false"

      runner.start

      expect(FileUtils).to have_received(:rm_rf).with(runner.configuration.cache_path)
    ensure
      ENV.delete(FixtureKit::Runner::PRESERVE_CACHE_ENV_KEY)
    end

    it "raises when called more than once" do
      runner = described_class.new

      runner.start

      expect { runner.start }.to raise_error(
        FixtureKit::RunnerAlreadyStartedError,
        "FixtureKit::Runner has already been started"
      )
    end

    it "does not cache already-registered fixtures at startup" do
      runner = described_class.new

      runner.start

      expect(fixture).not_to have_received(:generate)
    end
  end

  describe "#register" do
    it "adds named fixtures to the registry before suite start without caching them" do
      runner = described_class.new

      runner.register(fixture_name, scope)

      expect(registry).to have_received(:add).with(fixture_name, scope)
      expect(fixture).not_to have_received(:generate)
    end

    it "does not cache fixtures immediately after suite start" do
      runner = described_class.new
      runner.start

      fixture_name = "teams/basic"
      teams_fixture = instance_double(FixtureKit::Fixture, identifier: fixture_name, generate: nil)
      allow(registry).to receive(:add).with(fixture_name, scope).and_return(teams_fixture)

      runner.register(fixture_name, scope)

      expect(teams_fixture).not_to have_received(:generate)
    end

    it "returns the fixture instance from the registry" do
      runner = described_class.new

      expect(runner.register(fixture_name, scope)).to eq(fixture)
    end

    it "passes definition objects to the registry" do
      runner = described_class.new
      definition = FixtureKit::Definition.new { expose(example: "record") }

      runner.register(definition, scope)

      expect(registry).to have_received(:add).with(definition, scope)
    end

    it "passes definitions with extends to the registry" do
      runner = described_class.new
      definition = FixtureKit::Definition.new(extends: "teams/basic") { expose(example: "record") }

      runner.register(definition, scope)

      expect(registry).to have_received(:add).with(have_attributes(extends: "teams/basic"), scope)
    end

    it "runs on_register callbacks with the fixture event and the declaring scope" do
      runner = described_class.new
      received_event = nil
      received_scope = nil
      runner.configuration.on_register do |event, declaring_scope|
        received_event = event
        received_scope = declaring_scope
      end

      runner.register(fixture_name, scope)

      expect(received_event).to be_a(FixtureKit::Event)
      expect(received_event.fixture).to eq(fixture)
      expect(received_scope).to eq(scope)
    end
  end
end
