# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FixtureKit single test count integration" do
  fixture "teams/basic"

  it "runs one real example when using fixture data" do
    expect(fixture.alice.name).to eq("Alice")
    puts "FKIT_ASSERT:SINGLE_COUNT_TEST"
  end
end
