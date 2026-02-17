# frozen_string_literal: true

RSpec.describe FixturyBot::Configuration do
  subject(:config) { described_class.new }

  describe "#fixtures_path" do
    context "when spec directory exists" do
      before do
        allow(Dir).to receive(:exist?).with("spec").and_return(true)
      end

      it "defaults to spec/fixtures/fixtury_bot" do
        expect(config.fixtures_path).to eq("spec/fixtures/fixtury_bot")
      end
    end

    context "when test directory exists but spec does not" do
      before do
        allow(Dir).to receive(:exist?).with("spec").and_return(false)
        allow(Dir).to receive(:exist?).with("test").and_return(true)
      end

      it "defaults to test/fixtures/fixtury_bot" do
        expect(config.fixtures_path).to eq("test/fixtures/fixtury_bot")
      end
    end

    context "when overridden" do
      it "uses the custom path" do
        config.fixtures_path = "custom/fixtures"

        expect(config.fixtures_path).to eq("custom/fixtures")
      end
    end
  end

  describe "#autogenerate" do
    it "defaults to true" do
      expect(config.autogenerate).to be(true)
    end

    it "can be set to false" do
      config.autogenerate = false

      expect(config.autogenerate).to be(false)
    end
  end

  describe "#fixtury_path" do
    context "when spec directory exists" do
      before do
        allow(Dir).to receive(:exist?).with("spec").and_return(true)
      end

      it "defaults to spec/fixtury" do
        expect(config.fixtury_path).to eq("spec/fixtury")
      end
    end

    context "when overridden" do
      it "uses the custom path" do
        config.fixtury_path = "custom/fixtury"

        expect(config.fixtury_path).to eq("custom/fixtury")
      end
    end
  end
end
