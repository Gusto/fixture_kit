# frozen_string_literal: true

require "fixtury_bot/rspec"

RSpec.describe FixturyBot::RSpec do
  describe "#fixtury" do
    it "allows accessing records via method calls" do
      FixturyBot.define(:method_test) do
        expose(test_user: create(:user, name: "Test User"))
      end
      FixturyBot.generate(:method_test)
      FactoryBot.rewind_sequences
      User.delete_all
      FixturyBot.load_definitions(:method_test)

      expect(fixtury.test_user).to be_a(User)
      expect(fixtury.test_user.name).to eq("Test User")
    end

    it "allows accessing records via bracket notation" do
      FixturyBot.define(:bracket_test) do
        user = create(:user, name: "Test User")
        order = create(:order, user: user)
        expose(test_user: user, test_order: order)
      end
      FixturyBot.generate(:bracket_test)
      FactoryBot.rewind_sequences
      Order.delete_all
      User.delete_all
      FixturyBot.load_definitions(:bracket_test)

      expect(fixtury[:test_user]).to be_a(User)
      expect(fixtury[:test_order]).to be_a(Order)
    end

    it "raises for unknown records via method_missing" do
      FixturyBot.define(:missing_test) do
        expose(some_user: create(:user))
      end
      FixturyBot.generate(:missing_test)
      FactoryBot.rewind_sequences
      User.delete_all
      FixturyBot.load_definitions(:missing_test)

      expect { fixtury.nonexistent }.to raise_error(NoMethodError)
    end

    it "responds to exposed names" do
      FixturyBot.define(:respond_test) do
        expose(respond_user: create(:user))
      end
      FixturyBot.generate(:respond_test)
      FactoryBot.rewind_sequences
      User.delete_all
      FixturyBot.load_definitions(:respond_test)

      expect(fixtury.respond_to?(:respond_user)).to be(true)
      expect(fixtury.respond_to?(:nonexistent)).to be(false)
    end

    it "returns arrays for exposed lists" do
      FixturyBot.define(:list_test) do
        expose(users: create_list(:user, 3))
      end
      FixturyBot.generate(:list_test)
      FactoryBot.rewind_sequences
      User.delete_all
      FixturyBot.load_definitions(:list_test)

      expect(fixtury.users).to be_an(Array)
      expect(fixtury.users.size).to eq(3)
      expect(fixtury.users).to all(be_a(User))
    end
  end

  describe "#fixtury_record" do
    before do
      FixturyBot.define(:legacy_test) do
        expose(legacy_user: create(:user, name: "Legacy User"))
      end

      FixturyBot.generate(:legacy_test)
      FactoryBot.rewind_sequences
      User.delete_all
      FixturyBot.load_definitions(:legacy_test)
    end

    it "provides backwards compatible access" do
      expect(fixtury_record(:legacy_user)).to be_a(User)
    end
  end

  describe "DuplicateFixturyError" do
    it "raises when fixtury would be called multiple times" do
      FixturyBot.define(:dupe_fixtury_test) do
        expose(dupe_user: create(:user))
      end

      FixturyBot.generate(:dupe_fixtury_test)
      FactoryBot.rewind_sequences
      User.delete_all

      FixturyBot.load_definitions(:dupe_fixtury_test)

      expect(FixturyBot.current_fixture_set).not_to be_empty

      expect {
        if FixturyBot.current_fixture_set.any?
          previously_loaded = FixturyBot.current_fixture_set.keys.first(3).join(", ")
          raise FixturyBot::DuplicateFixturyError, <<~ERROR
            fixtury called multiple times for the same example.

            Already loaded fixtures include: #{previously_loaded}...
          ERROR
        end
      }.to raise_error(FixturyBot::DuplicateFixturyError, /fixtury called multiple times/)
    end
  end
end
