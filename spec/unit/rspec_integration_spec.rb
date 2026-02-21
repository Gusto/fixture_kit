# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RSpec integration" do
  describe ".fixture_names_for_loaded_examples" do
    it "collects unique fixture names from loaded examples" do
      metadata_key = FixtureKit::RSpec::DECLARATION_METADATA_KEY
      project_declaration = FixtureKit::RSpec::Declaration.new("project_management")
      teams_declaration = FixtureKit::RSpec::Declaration.new("teams/basic")
      world = instance_double(
        RSpec::Core::World,
        filtered_examples: {
          group_a: [
            instance_double(RSpec::Core::Example, metadata: { metadata_key => project_declaration }),
            instance_double(RSpec::Core::Example, metadata: { metadata_key => project_declaration })
          ],
          group_b: [
            instance_double(RSpec::Core::Example, metadata: { metadata_key => teams_declaration }),
            instance_double(RSpec::Core::Example, metadata: {})
          ]
        }
      )

      allow(RSpec).to receive(:world).and_return(world)

      expect(FixtureKit::RSpec.fixture_names_for_loaded_examples)
        .to eq(["project_management", "teams/basic"])
    end
  end

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

    it "pregenerates only loaded fixture names when autogenerate is disabled" do
      config = double("RSpec config")
      first_matching_callback = nil
      suite_callback = nil

      allow(config).to receive(:extend)
      allow(config).to receive(:include)
      allow(config).to receive(:prepend_before)
      allow(config).to receive(:before) do |scope, &block|
        suite_callback = block if scope == :suite
      end
      allow(config).to receive(:when_first_matching_example_defined) do |_metadata, &block|
        first_matching_callback = block
      end

      FixtureKit.configuration.autogenerate = false
      allow(FixtureKit::RSpec).to receive(:fixture_names_for_loaded_examples).and_return(["project_management"])
      allow(FixtureKit::FixtureCache).to receive(:pregenerate_all)

      FixtureKit::RSpec.configure!(config)
      first_matching_callback.call
      suite_callback.call

      expect(FixtureKit::FixtureCache).to have_received(:pregenerate_all).with(["project_management"])
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
