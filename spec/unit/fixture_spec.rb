# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe FixtureKit::Fixture do
  let(:cache_exists) { false }
  let(:cache) { instance_double(FixtureKit::Cache, exists?: cache_exists, save: nil) }
  let(:tmp_dir) { Dir.mktmpdir("fixture_kit_fixture_spec") }
  let(:fixture_path) { File.join(tmp_dir, "project_management.rb") }

  before do
    File.write(fixture_path, <<~RUBY)
      FixtureKit.define do
      end
    RUBY

    allow(FixtureKit::Cache).to receive(:new).and_return(cache)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#cache" do
    it "calls on_cache when generating cache for the first time" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      FixtureKit.configuration.on_cache = callback

      fixture.cache

      expect(cache).to have_received(:save)
      expect(callback).to have_received(:call).with("project_management")
    end

    it "does not call on_cache when cache already exists and force is false" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      FixtureKit.configuration.on_cache = callback
      allow(cache).to receive(:exists?).and_return(true)

      fixture.cache

      expect(cache).not_to have_received(:save)
      expect(callback).not_to have_received(:call)
    end

    it "does not call on_cache during forced regeneration of existing cache" do
      fixture = described_class.new("project_management", fixture_path)
      callback = spy("on_cache")
      FixtureKit.configuration.on_cache = callback
      allow(cache).to receive(:exists?).and_return(true)

      fixture.cache(force: true)

      expect(cache).to have_received(:save)
      expect(callback).not_to have_received(:call)
    end
  end
end
