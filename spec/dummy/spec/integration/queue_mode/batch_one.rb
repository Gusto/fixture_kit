# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Queue mode batch one" do
  fixture "queue_mode/initial_subset"

  it "runs the first batch and mounts fixture data from cache" do
    cache_file = File.join(FixtureKit.runner.configuration.cache_path, "queue_mode/initial_subset.json")

    expect(File.exist?(cache_file)).to be(true)
    expect(fixture.alpha.name).to eq("Queue Alpha")

    puts "FKIT_ASSERT:QMODE_BATCH1_RAN"
  end
end
