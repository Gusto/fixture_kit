# frozen_string_literal: true

require "securerandom"
require "spec_helper"

RSpec.describe FixtureKit::SqlSubscriber do
  EXPECTED_USER_WRITE_EVENT_NAMES = [
    "User Create",
    "User Update",
    "User Update All",
    "User Destroy",
    "User Delete All",
    "User Insert",
    "User Bulk Insert",
    "User Upsert",
    "User Bulk Upsert"
  ].freeze

  def exercise_user_write_operations(suffix)
    user = User.create!(name: "Create #{suffix}", email: "create-#{suffix}@example.com")
    user.update!(name: "Update #{suffix}")
    User.where(id: user.id).update_all(name: "Update All #{suffix}")

    User.insert_all!([
      { name: "Insert #{suffix}", email: "insert-#{suffix}@example.com" }
    ])

    User.insert_all!([
      { name: "Bulk Insert 1 #{suffix}", email: "bulk-insert-1-#{suffix}@example.com" },
      { name: "Bulk Insert 2 #{suffix}", email: "bulk-insert-2-#{suffix}@example.com" }
    ])

    User.upsert_all([
      { id: user.id, name: "Upsert #{suffix}", email: "create-#{suffix}@example.com" }
    ], unique_by: :id)

    User.upsert_all([
      { id: user.id, name: "Bulk Upsert Existing #{suffix}", email: "create-#{suffix}@example.com" },
      { id: user.id + 10_000_000, name: "Bulk Upsert New #{suffix}", email: "bulk-upsert-#{suffix}@example.com" }
    ], unique_by: :id)

    doomed = User.create!(name: "Delete #{suffix}", email: "delete-#{suffix}@example.com")
    User.where(id: doomed.id).delete_all

    destroyed = User.create!(name: "Destroy #{suffix}", email: "destroy-#{suffix}@example.com")
    destroyed.destroy!
  end

  describe ".capture" do
    it "captures user model writes for all supported write operation types" do
      suffix = SecureRandom.hex(6)

      models = described_class.capture do
        exercise_user_write_operations(suffix)
      end

      expect(models).to include(User)
    end

    it "resolves STI subclasses to their base table-owning model" do
      models = described_class.capture do
        Car.create!(name: "Sedan", year: 2024)
        Truck.create!(name: "Pickup", year: 2023)
      end

      expect(models).to contain_exactly(Vehicle)
    end
  end

  describe "sql.active_record payload name format assumptions" do
    it "emits the expected names for supported write operation types" do
      names = Set.new
      suffix = SecureRandom.hex(6)
      subscriber = lambda do |_event_name, _start, _finish, _id, payload|
        name = payload[:name].to_s
        next if name.empty? || name == "SCHEMA" || name == "TRANSACTION"

        names << name
      end

      ActiveSupport::Notifications.subscribed(subscriber, described_class::EVENT, monotonic: true) do
        exercise_user_write_operations(suffix)
      end

      EXPECTED_USER_WRITE_EVENT_NAMES.each do |expected_name|
        expect(names).to include(expected_name)
      end
    end
  end
end
