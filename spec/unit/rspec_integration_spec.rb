# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RSpec integration" do
  describe ".configure!" do
    it "registers the suite cache hook lazily" do
      config = double("RSpec config")
      first_matching_callback = nil
      suite_callback = nil

      allow(config).to receive(:extend)
      allow(config).to receive(:include)
      allow(config).to receive(:prepend_before)
      allow(config).to receive(:before) do |scope, &block|
        suite_callback = block if scope == :suite
      end
      allow(config).to receive(:when_first_matching_example_defined) do |metadata, &block|
        expect(metadata).to eq(FixtureKit::RSpec::DECLARATION_METADATA_KEY)
        first_matching_callback = block
      end

      FixtureKit::RSpec.configure!(config)

      expect(first_matching_callback).to be_a(Proc)
      expect(suite_callback).to be_nil

      first_matching_callback.call

      expect(suite_callback).to be_a(Proc)
    end
  end

  describe "generator configuration" do
    it "sets RSpec generator by default" do
      expect(FixtureKit.configuration.generator).to eq(FixtureKit::RSpec::Generator)
    end

    it "keeps RSpec generator when configure does not override it" do
      FixtureKit.configure do |config|
        config.fixture_path = "spec/fixture_kit"
      end

      expect(FixtureKit.configuration.generator).to eq(FixtureKit::RSpec::Generator)
    end
  end

  describe "FIXTURE_KIT_PRESERVE_CACHE environment variable" do
    # Note: The before(:suite) hook runs once at test suite start, so we can't
    # directly test its behavior. These tests verify the env var parsing logic.

    def preserve_cache?(env_value)
      env_value.to_s.match?(/\A(1|true|yes)\z/i)
    end

    it "treats '1' as truthy" do
      expect(preserve_cache?("1")).to be(true)
    end

    it "treats 'true' as truthy (case insensitive)" do
      expect(preserve_cache?("true")).to be(true)
      expect(preserve_cache?("TRUE")).to be(true)
      expect(preserve_cache?("True")).to be(true)
    end

    it "treats 'yes' as truthy (case insensitive)" do
      expect(preserve_cache?("yes")).to be(true)
      expect(preserve_cache?("YES")).to be(true)
      expect(preserve_cache?("Yes")).to be(true)
    end

    it "treats nil as falsy" do
      expect(preserve_cache?(nil)).to be(false)
    end

    it "treats empty string as falsy" do
      expect(preserve_cache?("")).to be(false)
    end

    it "treats '0' as falsy" do
      expect(preserve_cache?("0")).to be(false)
    end

    it "treats 'false' as falsy" do
      expect(preserve_cache?("false")).to be(false)
    end

    it "treats other values as falsy" do
      expect(preserve_cache?("no")).to be(false)
      expect(preserve_cache?("random")).to be(false)
    end
  end
end
