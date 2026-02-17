# frozen_string_literal: true

RSpec.describe FixturyBot::RecordTracker do
  subject(:tracker) { described_class.new }

  describe "#track" do
    it "stores record entries" do
      user = create(:user)

      entry = tracker.track(user, factory_name: :user)

      expect(tracker.records.size).to eq(1)
      expect(entry.record).to eq(user)
    end

    it "tracks database name" do
      user = create(:user)

      entry = tracker.track(user)

      expect(entry.database_name).to be_a(String)
    end

    it "generates auto name for all records" do
      user1 = create(:user)
      user2 = create(:user)

      tracker.track(user1)
      tracker.track(user2)

      expect(tracker.records.map(&:fixture_name)).to eq([:user_1, :user_2])
    end
  end

  describe "#rename" do
    it "changes the fixture name" do
      user = create(:user)
      tracker.track(user)

      tracker.rename(user, :admin)

      expect(tracker.find_by_name(:admin)).to eq(user)
      expect(tracker.find_by_name(:user_1)).to be_nil
    end

    it "raises on duplicate name" do
      user1 = create(:user)
      user2 = create(:user)
      tracker.track(user1)
      tracker.track(user2)

      tracker.rename(user1, :first)

      expect {
        tracker.rename(user2, :first)
      }.to raise_error(FixturyBot::DuplicateNameError, /Duplicate fixture name :first/)
    end

    it "raises if record is not tracked" do
      user = create(:user)

      expect {
        tracker.rename(user, :ghost)
      }.to raise_error(ArgumentError, /Record not tracked/)
    end
  end

  describe "#find_by_name" do
    it "returns the record for a given name" do
      user = create(:user)
      tracker.track(user)
      tracker.rename(user, :named_user)

      expect(tracker.find_by_name(:named_user)).to eq(user)
    end

    it "returns nil for unknown names" do
      expect(tracker.find_by_name(:unknown)).to be_nil
    end
  end

  describe "#find_by_model_and_id" do
    it "returns the fixture name for a record" do
      user = create(:user)
      tracker.track(user)
      tracker.rename(user, :lookup_user)

      expect(tracker.find_by_model_and_id(User, user.id)).to eq(:lookup_user)
    end
  end

  describe "#records_by_database" do
    it "groups records by database" do
      user = create(:user)
      event = create(:event)

      tracker.track(user)
      tracker.track(event)

      by_db = tracker.records_by_database

      # In single database setup, both are in the same database
      expect(by_db.values.flatten.map(&:fixture_name)).to contain_exactly(:user_1, :event_1)
    end
  end
end
