# frozen_string_literal: true

FixtureKit.define do
  sedan = Car.create!(name: "Sedan", year: 2024)
  pickup = Truck.create!(name: "Pickup", year: 2023)

  expose(sedan: sedan, pickup: pickup)
end
