# frozen_string_literal: true

RSpec.describe FixturyBot::FixtureSerializer do
  let(:fixtures_path) { "spec/fixtures/fixtury_bot" }

  describe "#serialize" do
    it "creates fixture files in the correct directory structure" do
      user = create(:user, name: "Test User")
      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :test_user)

      serializer = described_class.new(tracker.records, :test_fixtury, fixtures_path)
      path = serializer.serialize

      expect(Dir.exist?(path)).to be(true)
      expect(File.exist?(File.join(path, ".fixtury_bot.yml"))).to be(true)

      # Find the database directory
      db_dirs = Dir.glob(File.join(path, "*")).select { |f| File.directory?(f) }
      expect(db_dirs).not_to be_empty

      db_dir = db_dirs.first
      expect(File.exist?(File.join(db_dir, "users.yml"))).to be(true)
    end

    it "omits timestamp columns" do
      user = create(:user)
      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)

      serializer = described_class.new(tracker.records, :timestamps, fixtures_path)
      serializer.serialize

      # Find the database directory
      db_dirs = Dir.glob(File.join(fixtures_path, "timestamps", "*")).select { |f| File.directory?(f) }
      db_dir = db_dirs.first

      yaml_content = YAML.load_file(File.join(db_dir, "users.yml"))

      expect(yaml_content["user_1"].keys).not_to include("created_at", "updated_at")
    end

    it "resolves foreign key associations" do
      user = create(:user)
      order = create(:order, user: user)

      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :order_user)
      tracker.track(order)
      tracker.rename(order, :test_order)

      serializer = described_class.new(tracker.records, :associations, fixtures_path)
      serializer.serialize

      # Find the database directory
      db_dirs = Dir.glob(File.join(fixtures_path, "associations", "*")).select { |f| File.directory?(f) }
      db_dir = db_dirs.first

      yaml_content = YAML.load_file(File.join(db_dir, "orders.yml"))

      expect(yaml_content["test_order"]["user"]).to eq("order_user")
      expect(yaml_content["test_order"]).not_to have_key("user_id")
    end

    it "handles polymorphic associations" do
      user = create(:user)
      comment = create(:comment, commentable: user)

      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :commented_user)
      tracker.track(comment)
      tracker.rename(comment, :user_comment)

      serializer = described_class.new(tracker.records, :polymorphic, fixtures_path)
      serializer.serialize

      # Find the database directory
      db_dirs = Dir.glob(File.join(fixtures_path, "polymorphic", "*")).select { |f| File.directory?(f) }
      db_dir = db_dirs.first

      yaml_content = YAML.load_file(File.join(db_dir, "comments.yml"))

      expect(yaml_content["user_comment"]["commentable"]).to eq("commented_user (User)")
      expect(yaml_content["user_comment"]).not_to have_key("commentable_id")
      expect(yaml_content["user_comment"]).not_to have_key("commentable_type")
    end

    it "serializes decimal values correctly" do
      user = create(:user)
      order = create(:order, user: user, total: BigDecimal("99.99"))

      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :dec_user)
      tracker.track(order)
      tracker.rename(order, :dec_order)

      serializer = described_class.new(tracker.records, :decimals, fixtures_path)
      serializer.serialize

      # Find the database directory
      db_dirs = Dir.glob(File.join(fixtures_path, "decimals", "*")).select { |f| File.directory?(f) }
      db_dir = db_dirs.first

      yaml_content = YAML.load_file(File.join(db_dir, "orders.yml"))

      expect(yaml_content["dec_order"]["total"]).to eq("99.99")
    end

    it "stores source_digest in metadata when provided" do
      user = create(:user)
      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :digest_user)

      serializer = described_class.new(tracker.records, :digest_test, fixtures_path, source_digest: "abc123")
      serializer.serialize

      metadata = YAML.load_file(File.join(fixtures_path, "digest_test", ".fixtury_bot.yml"))

      expect(metadata["source_digest"]).to eq("abc123")
    end

    it "omits source_digest from metadata when nil" do
      user = create(:user)
      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :no_digest_user)

      serializer = described_class.new(tracker.records, :no_digest_test, fixtures_path)
      serializer.serialize

      metadata = YAML.load_file(File.join(fixtures_path, "no_digest_test", ".fixtury_bot.yml"))

      expect(metadata).not_to have_key("source_digest")
    end

    it "creates metadata file with database and exposed info" do
      user = create(:user)
      tracker = FixturyBot::RecordTracker.new
      tracker.track(user)
      tracker.rename(user, :meta_user)

      exposed = { meta_user: "meta_user" }
      serializer = described_class.new(tracker.records, :metadata_test, fixtures_path, exposed: exposed)
      serializer.serialize

      metadata = YAML.load_file(File.join(fixtures_path, "metadata_test", ".fixtury_bot.yml"))

      expect(metadata).to be_a(Hash)
      expect(metadata["databases"]).to be_a(Hash)
      expect(metadata["databases"].values).to include("User")
      expect(metadata["exposed"]).to eq({ "meta_user" => "meta_user" })
    end
  end
end
