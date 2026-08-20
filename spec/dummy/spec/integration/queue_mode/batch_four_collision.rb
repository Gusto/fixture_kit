# frozen_string_literal: true

require "rails_helper"

# Same description as batch_three_collision.rb. See the comment there.
RSpec.describe "Queue mode colliding description" do
  fixture do
    fourth = User.create!(name: "Queue Fourth", email: "queue.fourth@example.com")

    expose(fourth: fourth)
  end

  it "mounts its own anonymous fixture rather than the earlier batch's" do
    expect(fixture.fourth.name).to eq("Queue Fourth")

    puts "FKIT_ASSERT:QMODE_BATCH4_RAN"
  end
end
