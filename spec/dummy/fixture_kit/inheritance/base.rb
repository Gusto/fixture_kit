# frozen_string_literal: true

FixtureKit.define do
  owner = User.create!(name: "Inheritance Owner", email: "inheritance.owner@example.com")

  expose(owner: owner)
end
