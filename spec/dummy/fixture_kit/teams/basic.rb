# frozen_string_literal: true

FixtureKit.define do
  alice = User.create!(name: "Alice", email: "alice@team.test", role: "admin")
  bob = User.create!(name: "Bob", email: "bob@team.test")

  expose(
    alice: alice,
    bob: bob
  )
end
