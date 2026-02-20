# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Configuration do
  describe "#generator" do
    it "defaults to FixtureKit::Generator" do
      expect(described_class.new.generator).to eq(FixtureKit::Generator)
    end

    it "returns an explicitly configured class" do
      custom_generator_class = Class.new(FixtureKit::Generator)
      configuration = described_class.new
      configuration.generator = custom_generator_class

      expect(configuration.generator).to eq(custom_generator_class)
    end
  end
end
