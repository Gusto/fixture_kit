# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Singleton do
  describe ".configure" do
    it "yields the runner configuration" do
      yielded = nil

      FixtureKit.configure do |config|
        yielded = config
      end

      expect(yielded).to equal(FixtureKit.runner.configuration)
    end
  end

  describe ".reset" do
    it "resets runner" do
      FixtureKit.runner
      previous_runner = FixtureKit.runner

      FixtureKit.reset

      expect(FixtureKit.runner).not_to equal(previous_runner)
    end
  end

end
