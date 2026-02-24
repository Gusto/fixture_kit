# frozen_string_literal: true

require "test_helper"

class FixtureKitStiIntegrationTest < ActiveSupport::TestCase
  fixture "sti_vehicles"

  test "restores all STI subclass records sharing a table" do
    assert_equal 2, Vehicle.count
    assert_equal 1, Car.count
    assert_equal 1, Truck.count

    assert_kind_of Car, fixture.sedan
    assert_equal "Sedan", fixture.sedan.name
    assert_kind_of Truck, fixture.pickup
    assert_equal "Pickup", fixture.pickup.name
    puts "FKIT_ASSERT:STI_RECORDS_RESTORED"
  end

  test "does not duplicate records across rollback boundary" do
    assert_equal 2, Vehicle.count
    puts "FKIT_ASSERT:STI_ROLLBACK_CLEAN"
  end
end
