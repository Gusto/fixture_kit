# frozen_string_literal: true

RSpec.describe FixturyBot::Fixtury do
  describe "#source_file" do
    it "stores the source file when provided" do
      fixtury = described_class.new(:test, source_file: "/path/to/file.rb") {}

      expect(fixtury.source_file).to eq("/path/to/file.rb")
    end

    it "defaults to nil" do
      fixtury = described_class.new(:test) {}

      expect(fixtury.source_file).to be_nil
    end
  end

  describe "#execute" do
    it "creates records using Factory Bot" do
      fixtury = described_class.new(:test) do
        user = create(:user)
        expose(test_user: user)
      end

      result = fixtury.execute

      expect(result.records.size).to eq(1)
      expect(result.records.first.record).to be_a(User)
      expect(result.records.first.fixture_name).to eq(:test_user)
    end

    it "allows creating multiple records" do
      fixtury = described_class.new(:multi) do
        expose(user_one: create(:user), user_two: create(:user))
      end

      result = fixtury.execute

      expect(result.records.size).to eq(2)
      expect(result.records.map(&:fixture_name)).to contain_exactly(:user_one, :user_two)
    end

    it "supports factory traits" do
      fixtury = described_class.new(:with_traits) do
        expose(verified_user: create(:user, :verified))
      end

      result = fixtury.execute

      expect(result.records.first.record.verified).to be(true)
    end

    it "supports factory attributes" do
      fixtury = described_class.new(:with_attrs) do
        expose(custom_user: create(:user, name: "Custom Name"))
      end

      result = fixtury.execute

      expect(result.records.first.record.name).to eq("Custom Name")
    end

    context "with expose" do
      it "renames the fixture to the exposed name" do
        fixtury = described_class.new(:rename_test) do
          expose(admin: create(:user, name: "Admin"))
        end

        result = fixtury.execute

        expect(result.records.first.fixture_name).to eq(:admin)
        expect(result.exposed).to eq({ admin: "admin" })
      end

      it "exposes multiple records at once" do
        fixtury = described_class.new(:multi_expose) do
          user = create(:user)
          order = create(:order, user: user)
          expose(user:, order:)
        end

        result = fixtury.execute

        expect(result.records.size).to eq(2)
        expect(result.records.map(&:fixture_name)).to contain_exactly(:user, :order)
        expect(result.exposed.keys).to contain_exactly(:user, :order)
      end

      it "supports create_list" do
        fixtury = described_class.new(:list_test) do
          expose(users: create_list(:user, 3))
        end

        result = fixtury.execute

        expect(result.records.size).to eq(3)
        expect(result.records.map(&:fixture_name)).to eq([:user_1, :user_2, :user_3])
        expect(result.exposed[:users]).to eq(%w[user_1 user_2 user_3])
      end

      it "supports create_list referencing other records" do
        fixtury = described_class.new(:list_ref_test) do
          user = create(:user)
          orders = create_list(:order, 2, user: user)
          expose(test_user: user, orders:)
        end

        result = fixtury.execute

        expect(result.records.size).to eq(3) # 1 user + 2 orders
        orders = result.records.select { |r| r.record.is_a?(Order) }
        user = result.records.find { |r| r.fixture_name == :test_user }
        orders.each { |o| expect(o.record.user).to eq(user.record) }
      end

      it "raises on duplicate expose names" do
        fixtury = described_class.new(:dupe_expose) do
          expose(my_user: create(:user))
          expose(my_user: create(:user))
        end

        expect { fixtury.execute }.to raise_error(FixturyBot::DuplicateNameError, /Duplicate expose name :my_user/)
      end

      it "raises on duplicate expose names for lists" do
        fixtury = described_class.new(:dupe_list_expose) do
          expose(users: create_list(:user, 2))
          expose(users: create_list(:user, 3))
        end

        expect { fixtury.execute }.to raise_error(FixturyBot::DuplicateNameError, /Duplicate expose name :users/)
      end
    end

    context "with non-exposed records" do
      it "tracks non-exposed records with auto-generated names" do
        fixtury = described_class.new(:mixed) do
          create(:user) # not exposed
          expose(admin: create(:user))
        end

        result = fixtury.execute

        expect(result.records.size).to eq(2)
        expect(result.records.map(&:fixture_name)).to eq([:user_1, :admin])
        expect(result.exposed).to eq({ admin: "admin" })
      end
    end

    context "with auto-generated names" do
      it "generates sequential names when no expose is used" do
        fixtury = described_class.new(:auto_names) do
          create(:user)
          create(:user)
          create(:user)
        end

        result = fixtury.execute

        expect(result.records.map(&:fixture_name)).to eq([:user_1, :user_2, :user_3])
      end
    end
  end
end
