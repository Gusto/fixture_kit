# frozen_string_literal: true

FixtureKit.define do
  late_user = User.create!(name: "Queue Late", email: "queue.late@example.com")

  expose(late_user: late_user)
end
