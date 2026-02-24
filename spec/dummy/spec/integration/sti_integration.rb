# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FixtureKit STI integration" do
  describe "single table inheritance" do
    fixture "sti_vehicles"

    it "restores all STI subclass records sharing a table" do
      expect(Vehicle.count).to eq(2)
      expect(Car.count).to eq(1)
      expect(Truck.count).to eq(1)

      expect(fixture.sedan).to be_a(Car)
      expect(fixture.sedan.name).to eq("Sedan")
      expect(fixture.pickup).to be_a(Truck)
      expect(fixture.pickup.name).to eq("Pickup")
      puts "FKIT_ASSERT:STI_RECORDS_RESTORED"
    end

    it "does not duplicate records across rollback boundary" do
      expect(Vehicle.count).to eq(2)
      puts "FKIT_ASSERT:STI_ROLLBACK_CLEAN"
    end
  end
end
