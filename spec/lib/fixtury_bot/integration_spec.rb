# frozen_string_literal: true

RSpec.describe "FixturyBot Integration" do
  describe "full workflow" do
    it "defines fixturys, generates fixtures, and validates them" do
      FixturyBot.define(:integration_full) do
        user = create(:user, name: "Base User")
        order = create(:order, user: user, status: "pending")
        item = create(:line_item, order: order, product_name: "Widget")

        expose(base_user: user, test_order: order, test_item: item)
      end

      FixturyBot.generate(:integration_full)

      FactoryBot.rewind_sequences
      LineItem.delete_all
      Comment.delete_all
      Order.delete_all
      User.delete_all
      Event.delete_all

      fixtures_path = FixturyBot.configuration.fixtures_path
      fixtury_path = File.join(fixtures_path, "integration_full")

      expect(Dir.exist?(fixtury_path)).to be(true)

      db_dirs = Dir.glob(File.join(fixtury_path, "*")).select { |f| File.directory?(f) && !File.basename(f).start_with?(".") }
      expect(db_dirs).not_to be_empty

      db_dir = db_dirs.first

      expect(File.exist?(File.join(db_dir, "users.yml"))).to be(true)
      expect(File.exist?(File.join(db_dir, "orders.yml"))).to be(true)
      expect(File.exist?(File.join(db_dir, "line_items.yml"))).to be(true)

      users_yaml = YAML.load_file(File.join(db_dir, "users.yml"))
      expect(users_yaml["base_user"]["name"]).to eq("Base User")

      orders_yaml = YAML.load_file(File.join(db_dir, "orders.yml"))
      expect(orders_yaml["test_order"]["user"]).to eq("base_user")
      expect(orders_yaml["test_order"]["status"]).to eq("pending")

      items_yaml = YAML.load_file(File.join(db_dir, "line_items.yml"))
      expect(items_yaml["test_item"]["order"]).to eq("test_order")
      expect(items_yaml["test_item"]["product_name"]).to eq("Widget")

      result = FixturyBot.validate(:integration_full)
      expect(result.valid?).to be(true)
    end

    it "dumps all fixturys when no name specified" do
      FixturyBot.define(:dump_all_one) do
        expose(one_user: create(:user))
      end

      FixturyBot.define(:dump_all_two) do
        expose(two_user: create(:user))
      end

      FixturyBot.generate

      fixtures_path = FixturyBot.configuration.fixtures_path

      expect(Dir.exist?(File.join(fixtures_path, "dump_all_one"))).to be(true)
      expect(Dir.exist?(File.join(fixtures_path, "dump_all_two"))).to be(true)
    end

    it "handles events and multiple model types" do
      FixturyBot.define(:events_test) do
        user = create(:user, name: "Event User")
        event = create(:event, name: "User Created", data: user.id.to_s)
        expose(event_user: user, creation_event: event)
      end

      FixturyBot.generate(:events_test)

      fixtures_path = FixturyBot.configuration.fixtures_path
      fixtury_path = File.join(fixtures_path, "events_test")

      db_dirs = Dir.glob(File.join(fixtury_path, "*")).select { |f| File.directory?(f) && !File.basename(f).start_with?(".") }
      db_dir = db_dirs.first

      expect(File.exist?(File.join(db_dir, "users.yml"))).to be(true)
      expect(File.exist?(File.join(db_dir, "events.yml"))).to be(true)
    end

    it "integrates create_list with expose" do
      FixturyBot.define(:list_integration) do
        owner = create(:user, name: "Owner")
        orders = create_list(:order, 3, user: owner)
        expose(owner:, orders:)
      end

      FixturyBot.generate(:list_integration)

      FactoryBot.rewind_sequences
      LineItem.delete_all
      Comment.delete_all
      Order.delete_all
      User.delete_all
      Event.delete_all
      FixturyBot.load_definitions(:list_integration)

      expect(fixtury.owner).to be_a(User)
      expect(fixtury.orders).to be_an(Array)
      expect(fixtury.orders.size).to eq(3)
      expect(fixtury.orders).to all(be_a(Order))
      expect(fixtury.orders.first.user).to eq(fixtury.owner)
    end
  end
end
