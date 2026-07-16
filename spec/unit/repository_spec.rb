# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Repository do
  describe "#to_hash" do
    it "materializes every exposed record keyed by name" do
      alice = User.create!(name: "Alice", email: "alice-to-hash@example.com")
      bob = User.create!(name: "Bob", email: "bob-to-hash@example.com")

      repository = described_class.new(
        alice: { User => alice.id },
        bob: { User => bob.id }
      )

      expect(repository.to_hash).to eq(alice: alice, bob: bob)
    end

    it "materializes arrays of exposed records" do
      alice = User.create!(name: "Alice", email: "alice-array@example.com")
      bob = User.create!(name: "Bob", email: "bob-array@example.com")

      repository = described_class.new(
        users: [{ User => alice.id }, { User => bob.id }]
      )

      expect(repository.to_hash).to eq(users: [alice, bob])
    end

    it "uses symbol keys so it can be splatted into keyword arguments" do
      alice = User.create!(name: "Alice", email: "alice-splat@example.com")
      repository = described_class.new(owner: { User => alice.id })

      collected = ->(**records) { records }

      expect(collected.call(**repository)).to eq(owner: alice)
    end
  end
end
