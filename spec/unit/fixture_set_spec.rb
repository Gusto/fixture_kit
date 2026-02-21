# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Repository do
  describe "#initialize" do
    it "freezes array values" do
      records = { users: [1, 2, 3], admin: "single" }
      fixture_set = described_class.new(records)

      expect(fixture_set.users).to be_frozen
    end

    it "does not freeze non-array values" do
      hash_value = { name: "admin" }
      records = { admin: hash_value }
      fixture_set = described_class.new(records)

      expect(fixture_set.admin).not_to be_frozen
    end
  end
end
