# frozen_string_literal: true

FixtureKit.define do
  alice = create(:user, :admin, name: "Alice", email: "alice@team.test")
  bob = create(:user, name: "Bob", email: "bob@team.test")

  expose(
    alice: alice,
    bob: bob
  )
end
