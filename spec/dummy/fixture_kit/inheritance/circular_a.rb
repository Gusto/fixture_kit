# frozen_string_literal: true

FixtureKit.define(extends: "inheritance/circular_b") do
  expose(a: User.create!(name: "Circular A", email: "circular.a@example.com"))
end
