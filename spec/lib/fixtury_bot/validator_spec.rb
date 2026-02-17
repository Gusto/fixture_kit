# frozen_string_literal: true

RSpec.describe FixturyBot::Validator do
  let(:fixtures_path) { FixturyBot.configuration.fixtures_path }

  before do
    FixturyBot.define(:validation_test) do
      expose(val_user: create(:user, name: "Original Name"))
    end

    FixturyBot.generate(:validation_test)
  end

  describe "#validate" do
    def reset_for_validation
      # Reset Factory Bot sequences and clean database to simulate fresh validation run
      FactoryBot.rewind_sequences
      LineItem.delete_all
      Comment.delete_all
      Order.delete_all
      User.delete_all
      Event.delete_all
    end

    context "when fixtures match" do
      it "returns valid result" do
        reset_for_validation
        result = described_class.new(:validation_test).validate

        expect(result.valid?).to be(true)
        expect(result.differences).to be_empty
      end
    end

    context "when fixtures are stale" do
      it "detects attribute changes" do
        # Find the database directory dynamically
        fixtury_dir = File.join(fixtures_path, "validation_test")
        db_dirs = Dir.glob(File.join(fixtury_dir, "*")).select { |f| File.directory?(f) && !File.basename(f).start_with?(".") }
        db_dir = db_dirs.first

        yaml_path = File.join(db_dir, "users.yml")
        yaml_content = YAML.load_file(yaml_path)
        yaml_content["val_user"]["name"] = "Modified Name"
        File.write(yaml_path, yaml_content.to_yaml)

        reset_for_validation
        result = described_class.new(:validation_test).validate

        expect(result.valid?).to be(false)
        expect(result.differences[:validation_test].first[:type]).to eq(:modified)
        expect(result.differences[:validation_test].first[:changes]["name"]).to eq(
          { generated: "Original Name", committed: "Modified Name" }
        )
      end

      it "detects missing fixtures" do
        # Find the database directory dynamically
        fixtury_dir = File.join(fixtures_path, "validation_test")
        db_dirs = Dir.glob(File.join(fixtury_dir, "*")).select { |f| File.directory?(f) && !File.basename(f).start_with?(".") }
        db_dir = db_dirs.first

        yaml_path = File.join(db_dir, "users.yml")
        yaml_content = YAML.load_file(yaml_path)
        yaml_content["extra_fixture"] = { "name" => "Extra" }
        File.write(yaml_path, yaml_content.to_yaml)

        reset_for_validation
        result = described_class.new(:validation_test).validate

        expect(result.valid?).to be(false)

        removed = result.differences[:validation_test].find { |d| d[:type] == :removed }
        expect(removed[:fixture]).to eq("extra_fixture")
      end

      it "detects new fixtures" do
        FixturyBot.reset
        FixturyBot.configuration.output = StringIO.new
        FixturyBot.define(:validation_test) do
          expose(val_user: create(:user, name: "Original Name"))
          expose(new_user: create(:user, name: "New User"))
        end

        reset_for_validation
        result = described_class.new(:validation_test).validate

        expect(result.valid?).to be(false)

        new_fixture = result.differences[:validation_test].find { |d| d[:type] == :new }
        expect(new_fixture[:fixture]).to eq("new_user")
      end
    end

    context "when fixtury not found" do
      it "raises an error" do
        expect {
          described_class.new(:nonexistent).validate
        }.to raise_error(ArgumentError, /Fixtury 'nonexistent' not found/)
      end
    end

    context "when fixtures directory missing" do
      it "returns invalid result with error" do
        FileUtils.rm_rf(File.join(fixtures_path, "validation_test"))

        result = described_class.new(:validation_test).validate

        expect(result.valid?).to be(false)
        expect(result.differences[:validation_test][:error]).to match(/not found/)
      end
    end
  end
end
