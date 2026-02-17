# frozen_string_literal: true

RSpec.describe FixturyBot do
  describe ".configure" do
    it "yields a configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(FixturyBot::Configuration)
    end

    it "allows setting configuration options" do
      described_class.configure do |config|
        config.fixtury_path = "custom/fixtury"
        config.fixtures_path = "custom/fixtures"
      end

      expect(described_class.configuration.fixtury_path).to eq("custom/fixtury")
      expect(described_class.configuration.fixtures_path).to eq("custom/fixtures")
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(FixturyBot::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration

      expect(config1).to be(config2)
    end
  end

  describe ".define" do
    it "registers a fixtury" do
      described_class.define(:test_fixtury) do
        expose(test_user: create(:user))
      end

      expect(FixturyBot::FixturyRegistry.find(:test_fixtury)).not_to be_nil
    end
  end

  describe ".reset" do
    it "clears configuration" do
      described_class.configure do |config|
        config.fixtury_path = "custom/path"
      end

      described_class.reset

      expect(described_class.configuration.fixtury_path).not_to eq("custom/path")
    end

    it "clears fixtury registry" do
      described_class.define(:to_be_cleared) {}

      described_class.reset

      expect(FixturyBot::FixturyRegistry.find(:to_be_cleared)).to be_nil
    end
  end
end
