# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Repository do
  describe "ActiveRecord record access" do
    it "resolves _model/_id hashes to AR records" do
      user = User.create!(name: "Alice", email: "repo-test@example.com")
      repo = described_class.new(alice: { "_model" => "User", "_id" => user.id })

      expect(repo.alice).to eq(user)
    end

    it "resolves arrays of _model/_id hashes" do
      alice = User.create!(name: "Alice", email: "repo-arr-a@example.com")
      bob = User.create!(name: "Bob", email: "repo-arr-b@example.com")
      repo = described_class.new(users: [{ "_model" => "User", "_id" => alice.id }, { "_model" => "User", "_id" => bob.id }])

      expect(repo.users).to eq([alice, bob])
    end
  end

  describe "primitive value access" do
    it "returns primitives directly without DB query" do
      repo = described_class.new(
        label: "admin",
        count: 42,
        active: true,
        deleted: false,
        nothing: nil,
        metadata: { "role" => "admin" },
        tags: [1, 2, 3]
      )

      expect(repo.label).to eq("admin")
      expect(repo.count).to eq(42)
      expect(repo.active).to eq(true)
      expect(repo.deleted).to eq(false)
      expect(repo.nothing).to be_nil
      expect(repo.metadata).to eq({ "role" => "admin" })
      expect(repo.tags).to eq([1, 2, 3])
    end
  end

  describe "nested ActiveRecord values" do
    it "recursively resolves AR records in hashes, arrays, and deeply nested structures" do
      user = User.create!(name: "Alice", email: "repo-nested@example.com")
      model_hash = { "_model" => "User", "_id" => user.id }

      repo = described_class.new(
        in_hash: { "user" => model_hash, "label" => "admin" },
        in_array: ["tag", model_hash],
        deep: { "nested" => { "user" => model_hash } }
      )

      expect(repo.in_hash).to eq({ "user" => user, "label" => "admin" })
      expect(repo.in_array).to eq(["tag", user])
      expect(repo.deep).to eq({ "nested" => { "user" => user } })
    end
  end
end
