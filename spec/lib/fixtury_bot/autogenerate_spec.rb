# frozen_string_literal: true

require "tempfile"
require "digest"

RSpec.describe "FixturyBot autogenerate" do
  describe "when fixtures are missing" do
    context "with autogenerate=true (default)" do
      it "auto-generates and loads fixtures" do
        FixturyBot.define(:auto_missing) do
          expose(user: create(:user, name: "Auto User"))
        end

        result = FixturyBot.load_definitions(:auto_missing)

        expect(result[:user]).to be_a(User)
        expect(result[:user].name).to eq("Auto User")
      end

      it "cleans up DB records from generation via transaction rollback" do
        FixturyBot.define(:auto_cleanup) do
          expose(user: create(:user, name: "Cleanup User"))
        end

        expect(User.count).to eq(0)

        FixturyBot.load_definitions(:auto_cleanup)

        # Only the fixture-loaded record should exist (not the FactoryBot.create from generation)
        expect(User.count).to eq(1)
      end
    end

    context "with autogenerate=false" do
      before do
        FixturyBot.configuration.autogenerate = false
      end

      it "raises ArgumentError" do
        FixturyBot.define(:auto_missing_strict) do
          expose(user: create(:user))
        end

        expect {
          FixturyBot.load_definitions(:auto_missing_strict)
        }.to raise_error(ArgumentError, /not found/)
      end
    end
  end

  describe "when fixtures are stale" do
    context "with autogenerate=true (default)" do
      it "auto-regenerates stale fixtures" do
        tmpfile = Tempfile.new(["fixtury_source", ".rb"])
        tmpfile.write("# initial content")
        tmpfile.flush

        fixtury = FixturyBot::Fixtury.new(:auto_stale, source_file: tmpfile.path) do
          expose(user: create(:user, name: "Stale User"))
        end
        FixturyBot::FixturyRegistry.register(fixtury)

        # Generate fixtures (stores SHA256 of initial content)
        FixturyBot.generate(:auto_stale)

        # Clean up DB records created by generate
        FactoryBot.rewind_sequences
        User.delete_all

        # Modify the source file to make fixtures stale
        File.write(tmpfile.path, "# modified content")

        # load_definitions should detect staleness and auto-regenerate
        result = FixturyBot.load_definitions(:auto_stale)

        expect(result[:user]).to be_a(User)
        expect(result[:user].name).to eq("Stale User")
      ensure
        tmpfile&.close!
      end
    end

    context "with autogenerate=false" do
      before do
        FixturyBot.configuration.autogenerate = false
      end

      it "raises StaleFixturesError" do
        tmpfile = Tempfile.new(["fixtury_source", ".rb"])
        tmpfile.write("# initial content")
        tmpfile.flush

        fixtury = FixturyBot::Fixtury.new(:stale_strict, source_file: tmpfile.path) do
          expose(user: create(:user))
        end
        FixturyBot::FixturyRegistry.register(fixtury)

        # Generate fixtures
        FixturyBot.generate(:stale_strict)

        # Clean up DB records
        FactoryBot.rewind_sequences
        User.delete_all

        # Modify source file
        File.write(tmpfile.path, "# modified content")

        expect {
          FixturyBot.load_definitions(:stale_strict)
        }.to raise_error(FixturyBot::StaleFixturesError, /stale/)
      ensure
        tmpfile&.close!
      end
    end
  end

  describe "when fixtures exist and are fresh" do
    it "loads without regenerating" do
      tmpfile = Tempfile.new(["fixtury_source", ".rb"])
      tmpfile.write("# stable content")
      tmpfile.flush

      fixtury = FixturyBot::Fixtury.new(:fresh_test, source_file: tmpfile.path) do
        expose(user: create(:user, name: "Fresh User"))
      end
      FixturyBot::FixturyRegistry.register(fixtury)

      # Generate fixtures
      FixturyBot.generate(:fresh_test)

      # Clean up DB records from generate
      FactoryBot.rewind_sequences
      User.delete_all

      # load_definitions should load directly without regenerating
      result = FixturyBot.load_definitions(:fresh_test)

      expect(result[:user]).to be_a(User)
      expect(result[:user].name).to eq("Fresh User")
    ensure
      tmpfile&.close!
    end
  end

  describe "source_digest in metadata" do
    it "stores source_digest when source_file is present" do
      tmpfile = Tempfile.new(["fixtury_source", ".rb"])
      tmpfile.write("# some content")
      tmpfile.flush

      fixtury = FixturyBot::Fixtury.new(:digest_meta, source_file: tmpfile.path) do
        expose(user: create(:user))
      end
      FixturyBot::FixturyRegistry.register(fixtury)

      FixturyBot.generate(:digest_meta)

      metadata_path = File.join(FixturyBot.configuration.fixtures_path, "digest_meta", ".fixtury_bot.yml")
      metadata = YAML.load_file(metadata_path, permitted_classes: [Symbol])

      expected_digest = Digest::SHA256.file(tmpfile.path).hexdigest
      expect(metadata["source_digest"]).to eq(expected_digest)
    ensure
      tmpfile&.close!
    end

    it "does not store source_digest when source_file is nil" do
      fixtury = FixturyBot::Fixtury.new(:no_digest, source_file: nil) do
        expose(user: create(:user))
      end
      FixturyBot::FixturyRegistry.register(fixtury)

      FixturyBot.generate(:no_digest)

      metadata_path = File.join(FixturyBot.configuration.fixtures_path, "no_digest", ".fixtury_bot.yml")
      metadata = YAML.load_file(metadata_path, permitted_classes: [Symbol])

      expect(metadata).not_to have_key("source_digest")
    end
  end
end
