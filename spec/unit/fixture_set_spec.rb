# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Repository do
  describe "lazy exposed record loading" do
    it "loads a single exposed record on first access and memoizes it" do
      user = User.create!(name: "Memoized User", email: "memoized@example.com")
      repository = described_class.new(
        {
          admin: { User => user.id }
        }
      )

      expect(User).to receive(:find_by).with(id: user.id).once.and_call_original

      first = repository.admin
      second = repository.admin

      expect(first).to be_a(User)
      expect(first.id).to eq(user.id)
      expect(second).to equal(first)
    end

    it "loads array exposures lazily, memoizes, and freezes the loaded array" do
      user_one = User.create!(name: "Array User 1", email: "array-user-1@example.com")
      user_two = User.create!(name: "Array User 2", email: "array-user-2@example.com")
      repository = described_class.new(
        {
          users: [
            { User => user_one.id },
            { User => user_two.id }
          ]
        }
      )

      expect(User).to receive(:find_by).with(id: user_one.id).once.and_call_original
      expect(User).to receive(:find_by).with(id: user_two.id).once.and_call_original

      first = repository.users
      second = repository.users

      expect(first.map(&:id)).to eq([user_one.id, user_two.id])
      expect(second).to equal(first)
      expect(first).to be_frozen
    end

    it "does not load other exposures when one accessor is called" do
      user = User.create!(name: "Primary User", email: "primary-user@example.com")
      other_user = User.create!(name: "Other User", email: "other-user@example.com")
      repository = described_class.new(
        {
          user: { User => user.id },
          other_user: { User => other_user.id }
        }
      )

      expect(User).to receive(:find_by).with(id: user.id).once.and_call_original
      expect(User).not_to receive(:find_by).with(id: other_user.id)

      expect(repository.user.id).to eq(user.id)
    end

    it "returns nil when exposed record cannot be loaded" do
      repository = described_class.new(
        {
          missing_user: { User => 999_999 }
        }
      )

      expect(repository.missing_user).to be_nil
    end

    it "loads the latest persisted state when a record changes before first access" do
      user = User.create!(name: "Original User", email: "updated-before-access@example.com")
      repository = described_class.new(
        {
          user: { User => user.id }
        }
      )

      user.update!(name: "Updated Before Access")

      expect(repository.user.name).to eq("Updated Before Access")
    end

    it "returns nil when a record is deleted before first access" do
      user = User.create!(name: "Soon Missing", email: "soon-missing@example.com")
      repository = described_class.new(
        {
          user: { User => user.id }
        }
      )

      user.destroy!

      expect(repository.user).to be_nil
    end
  end
end
