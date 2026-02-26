# frozen_string_literal: true

FixtureKit.define(extends: "inheritance/circular_a") do
  expose(b: User.create!(name: "Circular B", email: "circular.b@example.com"))
end
