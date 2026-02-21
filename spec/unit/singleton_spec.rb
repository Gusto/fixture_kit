# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Singleton do
  describe ".reset" do
    before do
      FixtureKit::Cache.memory_cache["test_fixture"] = { "records" => {} }
    end

    it "clears memory cache" do
      FixtureKit.reset

      expect(FixtureKit::Cache.memory_cache).to be_empty
    end
  end

end
