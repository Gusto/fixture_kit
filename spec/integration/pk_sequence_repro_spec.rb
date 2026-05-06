# frozen_string_literal: true

require "spec_helper"

# Reproduces issue #51: when a cached fixture is mounted onto a database whose
# PK generator has not seen the inserted ids (e.g. a parallel test worker with
# its own DB copy), a subsequent Model.create can collide with one of the
# explicit ids the cache replayed. Postgres exhibits this; MySQL/SQLite advance
# their counters from explicit-id inserts and stay safe.
RSpec.describe "Primary key sequence after fixture mount" do
  fixture do
    User.create!(name: "Alice PK Repro", email: "alice-pk-repro@example.com")
    User.create!(name: "Bob PK Repro", email: "bob-pk-repro@example.com")
  end

  after do
    User.connection.disable_referential_integrity do
      User.connection.execute("DELETE FROM #{User.quoted_table_name}")
    end
  end

  it "lets a new record be created without colliding with replayed explicit ids" do
    # Simulate a parallel-worker scenario: empty table, PK generator at its
    # initial value. The fixture's auto-mount already populated the table for
    # us, so wipe and reset before re-mounting.
    wipe_and_reset_pk!(User)

    declaration = self.class.metadata[FixtureKit::RSpec::DECLARATION_METADATA_KEY]
    declaration.mount

    expect {
      User.create!(name: "Charlie PK Repro", email: "charlie-pk-repro@example.com")
    }.not_to raise_error
  end

  def wipe_and_reset_pk!(model)
    connection = model.connection
    connection.disable_referential_integrity do
      connection.execute("DELETE FROM #{model.quoted_table_name}")
    end

    case connection.adapter_name.to_s.downcase
    when "postgresql"
      sequence = connection.pk_and_sequence_for(model.table_name)&.last
      connection.execute("ALTER SEQUENCE #{sequence} RESTART WITH 1") if sequence
    when "mysql", "mysql2", "trilogy"
      # MySQL advances AUTO_INCREMENT on explicit-id INSERTs, so the counter
      # already keeps up with the cached ids. ALTER TABLE ... AUTO_INCREMENT
      # implicitly commits, which would break the surrounding transactional
      # fixture, so we leave it alone. The test should still pass on MySQL.
    when "sqlite"
      if connection.data_source_exists?("sqlite_sequence")
        connection.execute("DELETE FROM sqlite_sequence WHERE name = #{connection.quote(model.table_name)}")
      end
    else
      raise "Unsupported adapter for PK reset: #{connection.adapter_name.inspect}"
    end
  end
end
