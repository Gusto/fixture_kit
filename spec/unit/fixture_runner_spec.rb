# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Runner do
  let(:scope) { Class.new }
  let(:fixture_name) { "project_management" }
  let(:fixture) { instance_double(FixtureKit::Fixture, identifier: fixture_name, cache: nil) }
  let(:registry) { instance_double(FixtureKit::Registry, fixtures: [fixture]) }

  before do
    allow(FixtureKit::Registry).to receive(:new).and_return(registry)
    allow(registry).to receive(:add).and_return(fixture)
  end

  describe "#isolator" do
    it "instantiates the configured isolator once and memoizes it" do
      runner = described_class.new
      isolator_instance = instance_double(FixtureKit::MinitestIsolator)
      isolator_class = class_double(FixtureKit::MinitestIsolator, new: isolator_instance)
      runner.configuration.isolator = isolator_class

      first_isolator = runner.isolator
      second_isolator = runner.isolator

      expect(first_isolator).to equal(isolator_instance)
      expect(second_isolator).to equal(isolator_instance)
      expect(isolator_class).to have_received(:new).once
    end
  end

  describe "#start" do
    it "clears all cache files before caching fixtures" do
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

    it "caches already-registered fixtures when the suite starts" do
      runner = described_class.new

      runner.start

      expect(fixture).to have_received(:cache)
    end
  end

  describe "#register" do
    it "adds fixtures to the registry before suite start without caching them" do
      runner = described_class.new

      runner.register(scope, fixture_name)

      expect(registry).to have_received(:add).with(scope, fixture_name)
      expect(fixture).not_to have_received(:cache)
    end

    it "caches fixtures immediately after suite start" do
      runner = described_class.new
      runner.start

      fixture_name = "teams/basic"
      teams_fixture = instance_double(FixtureKit::Fixture, identifier: fixture_name, cache: nil)
      allow(registry).to receive(:add).with(scope, fixture_name).and_return(teams_fixture)

      runner.register(scope, fixture_name)

      expect(teams_fixture).to have_received(:cache)
    end

    it "returns the fixture instance from the registry" do
      runner = described_class.new

      expect(runner.register(scope, fixture_name)).to eq(fixture)
    end

    it "passes anonymous fixture definitions to the registry" do
      runner = described_class.new

      runner.register(scope) { expose(example: "record") }

      expect(registry).to have_received(:add).with(scope, kind_of(Proc))
    end

    it "raises when both a fixture name and a definition block are provided" do
      runner = described_class.new

      expect do
        runner.register(scope, fixture_name) { expose(example: "record") }
      end.to raise_error(
        FixtureKit::InvalidFixtureDeclaration,
        "cannot provide both fixture name and definition block"
      )
    end

    it "raises when neither a fixture name nor a definition block is provided" do
      runner = described_class.new

      expect do
        runner.register(scope)
      end.to raise_error(
        FixtureKit::InvalidFixtureDeclaration,
        "must provide fixture name or definition block"
      )
    end
  end
end
