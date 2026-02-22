# frozen_string_literal: true

FixtureKit.define do
  alpha = User.create!(name: "Queue Alpha", email: "queue.alpha@example.com")

  expose(alpha: alpha)
end
