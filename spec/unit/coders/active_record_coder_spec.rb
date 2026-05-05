# frozen_string_literal: true

require "securerandom"
require "spec_helper"

RSpec.describe FixtureKit::ActiveRecordCoder do
  let(:coder) { described_class.new }

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

  describe "#observe" do
    it "captures user model writes for all supported write operation types" do
      suffix = SecureRandom.hex(6)

      coder.observe { exercise_user_write_operations(suffix) }

      expect(coder.save).to have_key(User)
    end

    it "resolves STI subclasses to their base table-owning model" do
      coder.observe do
        Car.create!(name: "Sedan", year: 2024)
        Truck.create!(name: "Pickup", year: 2023)
      end

      expect(coder.save.keys).to contain_exactly(Vehicle)
    end

    it "resolves STI subclasses whose base model inherits directly from ActiveRecord::Base" do
      coder.observe do
        Phone.create!(name: "iPhone")
        Tablet.create!(name: "iPad")
      end

      expect(coder.save.keys).to contain_exactly(Gadget)
    end

    it "captures models written with update operations" do
      user = User.create!(name: "Alice", email: "alice-update@example.com")

      coder.observe do
        User.find(user.id).update!(name: "Alice Updated")
      end

      expect(coder.save).to have_key(User)
    end

    it "captures models written with delete and destroy operations" do
      User.create!(name: "Alice", email: "alice-delete@example.com")
      doomed = User.create!(name: "Bob", email: "bob-delete@example.com")

      coder.observe { doomed.destroy! }

      expect(coder.save).to have_key(User)
    end
  end

  describe "#save" do
    it "generates INSERT statements for captured models" do
      User.create!(name: "Alice", email: "alice-save@example.com")

      coder.observe { User.create!(name: "Bob", email: "bob-save@example.com") }

      result = coder.save
      expect(result[User]).to match(/INSERT INTO/)
    end

    it "stores nil sql for a model when its table is empty after changes" do
      user = User.create!(name: "Alice", email: "alice-empty@example.com")

      coder.observe { user.destroy! }

      expect(coder.save[User]).to be_nil
    end

    it "includes models from parent_data that were not directly captured" do
      User.create!(name: "Alice", email: "alice-parent@example.com")
      coder.observe { Project.create!(name: "Project", owner: User.find_by!(email: "alice-parent@example.com")) }

      parent_data = { User => "INSERT INTO users ..." }
      result = coder.save(parent_data: parent_data)

      expect(result.keys).to include(User, Project)
    end
  end

  describe "#mount" do
    it "documents that connection execute_batch is currently private" do
      connection = User.connection

      expect(connection.respond_to?(:execute_batch, true)).to be(true)
      expect(connection.private_methods).to include(:execute_batch)
      expect(connection.public_methods).not_to include(:execute_batch)
    end

    it "aggregates restore queries and executes one batch per connection" do
      user_sql = "INSERT INTO users (id, name) VALUES (1, 'Alice')"
      project_sql = "INSERT INTO projects (id, name, owner_id) VALUES (1, 'Website', 1)"
      activity_log_sql = "INSERT INTO activity_logs (id, action) VALUES (1, 'created')"

      records = {
        User => user_sql,
        Project => project_sql,
        ActivityLog => activity_log_sql
      }

      primary_connection = User.connection
      analytics_connection = ActivityLog.connection
      primary_statements = [
        "DELETE FROM #{User.quoted_table_name}",
        user_sql,
        "DELETE FROM #{Project.quoted_table_name}",
        project_sql
      ]
      analytics_statements = [
        "DELETE FROM #{ActivityLog.quoted_table_name}",
        activity_log_sql
      ]

      expect(primary_connection).to receive(:disable_referential_integrity).once.and_yield
      expect(primary_connection).to receive(:execute_batch).with(primary_statements, "FixtureKit Load").once
      expect(analytics_connection).to receive(:disable_referential_integrity).once.and_yield
      expect(analytics_connection).to receive(:execute_batch).with(analytics_statements, "FixtureKit Load").once

      coder.mount(records)
    end
  end

  describe "sql.active_record payload name format assumptions" do
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
