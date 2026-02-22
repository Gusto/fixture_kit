# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Queue mode batch two" do
  fixture "queue_mode/late_subset"

  it "runs a late-loaded batch and mounts its fixture" do
    cache_file = File.join(FixtureKit.runner.configuration.cache_path, "queue_mode/late_subset.json")

    expect(File.exist?(cache_file)).to be(true)
    expect(fixture.late_user.name).to eq("Queue Late")

    puts "FKIT_ASSERT:QMODE_BATCH2_RAN"
    puts "FKIT_ASSERT:QMODE_LATE_CACHE_GENERATED"
  end
end
