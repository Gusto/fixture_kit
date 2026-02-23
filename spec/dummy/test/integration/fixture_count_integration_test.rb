# frozen_string_literal: true

require "test_helper"

class FixtureKitSingleCountIntegrationTest < ActiveSupport::TestCase
  fixture "teams/basic"

  test "runs one real test when using fixture data" do
    assert_equal "Alice", fixture.alice.name
    puts "FKIT_ASSERT:SINGLE_COUNT_TEST"
  end
end
