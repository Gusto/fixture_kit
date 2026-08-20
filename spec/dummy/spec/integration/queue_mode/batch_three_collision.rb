# frozen_string_literal: true

require "rails_helper"

# Declares the same top-level description as batch_four_collision.rb, so both
# groups are named RSpec::ExampleGroups::QueueModeCollidingDescription: the
# constant is removed by RSpec::Core::World#reset between batches, so the
# duplicate-name counter never disambiguates them.
RSpec.describe "Queue mode colliding description" do
  fixture do
    third = User.create!(name: "Queue Third", email: "queue.third@example.com")

    expose(third: third)
  end

  it "mounts its own anonymous fixture" do
    expect(fixture.third.name).to eq("Queue Third")

    puts "FKIT_ASSERT:QMODE_BATCH3_RAN"
  end
end
