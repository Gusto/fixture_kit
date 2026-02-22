# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe FixtureKit::Fixture do
  let(:cache_exists) { false }
  let(:cache) { instance_double(FixtureKit::Cache, exists?: cache_exists, save: nil) }
  let(:runner) { FixtureKit::Runner.new }
  let(:configuration) { runner.configuration }
  let(:tmp_dir) { Dir.mktmpdir("fixture_kit_fixture_spec") }
  let(:fixture_path) { File.join(tmp_dir, "project_management.rb") }

  before do
    File.write(fixture_path, <<~RUBY)
      FixtureKit.define do
      end
    RUBY

    allow(FixtureKit::Cache).to receive(:new).and_return(cache)
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#cache" do
    it "calls on_cache before saving when generating cache for the first time" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      configuration.on_cache = callback

      expect(callback).to receive(:call).with("project_management").ordered
      expect(cache).to receive(:save).ordered

      fixture.cache

    end

    it "does not call on_cache when cache already exists and force is false" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      configuration.on_cache = callback
      allow(cache).to receive(:exists?).and_return(true)

      fixture.cache

      expect(cache).not_to have_received(:save)
      expect(callback).not_to have_received(:call)
    end

    it "calls on_cache during forced regeneration of existing cache" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      configuration.on_cache = callback
      allow(cache).to receive(:exists?).and_return(true)

      expect(callback).to receive(:call).with("project_management").ordered
      expect(cache).to receive(:save).ordered

      fixture.cache(force: true)

    end
  end
end
