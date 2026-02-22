# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RSpec integration" do
  describe "FixtureKit::RSpec::ClassMethods#fixture" do
    it "registers the fixture name through the runner and stores declaration metadata" do
      fixture = instance_double(FixtureKit::Fixture)
      runner = instance_double(FixtureKit::Runner, register: fixture)
      group_class = Class.new do
        extend FixtureKit::RSpec::ClassMethods

        def self.metadata
          @metadata ||= {}
        end
      end

      allow(RSpec.configuration).to receive(:fixture_kit).and_return(runner)

      group_class.fixture("project_management")

      expect(runner).to have_received(:register).with("project_management")
      expect(group_class.metadata[FixtureKit::RSpec::DECLARATION_METADATA_KEY]).to eq(fixture)
    end
  end

  describe ".configure!" do
    let(:config) { double("RSpec config") }
    let(:configuration) { FixtureKit::Configuration.new }
    let(:runner) { instance_double(FixtureKit::Runner, start: nil, configuration: configuration) }
    let(:fixture) { instance_double(FixtureKit::Fixture, mount: :fixture_set) }

    before do
      allow(FixtureKit).to receive(:runner).and_return(runner)
      allow(config).to receive(:add_setting)
      allow(config).to receive(:fixture_kit).and_return(runner)
      allow(config).to receive(:extend)
      allow(config).to receive(:include)
    end

    it "registers lifecycle hooks and starts the runner at suite start" do
      prepend_callback = nil
      suite_callback = nil

      allow(config).to receive(:prepend_before) do |_scope, _metadata_key, &block|
        prepend_callback = block
      end
      allow(config).to receive(:append_before) do |scope, &block|
        suite_callback = block if scope == :suite
      end

      FixtureKit::RSpec.configure!(config)

      expect(config).to have_received(:add_setting).with(
        :fixture_kit,
        default: runner
      )
      expect(prepend_callback).to be_a(Proc)
      expect(suite_callback).to be_a(Proc)

      suite_callback.call
      expect(runner).to have_received(:start)
    end

    it "loads fixture_set in prepend_before hook" do
      prepend_callback = nil
      example = instance_double(RSpec::Core::Example, metadata: { FixtureKit::RSpec::DECLARATION_METADATA_KEY => fixture })
      hook_host = Object.new

      allow(config).to receive(:prepend_before) do |_scope, _metadata_key, &block|
        prepend_callback = block
      end
      allow(config).to receive(:append_before)

      FixtureKit::RSpec.configure!(config)
      hook_host.instance_exec(example, &prepend_callback)

      expect(fixture).to have_received(:mount)
      expect(hook_host.instance_variable_get(:@_fixture_kit_fixture_set)).to eq(:fixture_set)
    end
  end

  describe "isolator configuration" do
    it "sets RSpec isolator by default" do
      expect(FixtureKit.configuration.isolator).to eq(FixtureKit::RSpec::Isolator)
    end

    it "keeps RSpec isolator when configure does not override it" do
      FixtureKit.configure do |config|
        config.fixture_path = "spec/fixture_kit"
      end

      expect(FixtureKit.configuration.isolator).to eq(FixtureKit::RSpec::Isolator)
    end
  end
end
