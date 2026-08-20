# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::Definition do
  describe "#extends" do
    it "stores parent fixture name for inherited definitions" do
      definition = described_class.new(extends: "teams/basic") {}

      expect(definition.extends).to eq("teams/basic")
    end
  end

  describe "#evaluate" do
    let(:alice) { User.create!(name: "Alice", email: "alice-definition@example.com") }

    it "captures exposed records from the definition block" do
      record = alice
      definition = described_class.new do
        expose(alice: record)
      end

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ alice: { User => alice.id } })
    end

    it "supports helper methods from execution context" do
      record = alice
      helper_context = Class.new do
        define_method(:fixture_record) { record }
      end.new

      definition = described_class.new do
        expose(alice: fixture_record)
      end

      definition.evaluate(helper_context)

      expect(definition.exposed).to eq({ alice: { User => alice.id } })
    end

    it "supports parent helper in execution context" do
      parent_repository = Struct.new(:owner).new(alice)
      definition = described_class.new do
        expose(owner: parent.owner)
      end

      definition.evaluate(Object.new, parent: parent_repository)

      expect(definition.exposed).to eq({ owner: { User => alice.id } })
    end
  end

  describe "#path" do
    it "returns the file path where the definition block was defined" do
      definition = described_class.new {}

      expect(definition.path).to eq(__FILE__)
    end
  end

  describe "#location" do
    it "returns the file and line where the definition block was defined" do
      definition = described_class.new {}

      expect(definition.location).to eq("#{__FILE__}:#{__LINE__ - 2}")
    end
  end

  describe "#fingerprint" do
    it "differs between declarations on different lines" do
      first = described_class.new {}
      second = described_class.new {}

      expect(first.fingerprint).not_to eq(second.fingerprint)
    end

    it "differs between declarations extending different parents" do
      definition_for = ->(extends) { described_class.new(extends: extends) {} }

      expect(definition_for.call("teams/basic").fingerprint).not_to eq(
        definition_for.call("teams/admin").fingerprint
      )
    end

    it "matches for two definitions built from the same declaration" do
      definition_for = -> { described_class.new(extends: "teams/basic") {} }

      expect(definition_for.call.fingerprint).to eq(definition_for.call.fingerprint)
    end
  end

  describe "#expose" do
    it "raises when the same name is exposed twice" do
      alice = User.create!(name: "Alice", email: "alice-duplicate@example.com")
      definition = described_class.new do
        expose(alice: alice)
        expose(alice: alice)
      end

      expect do
        definition.evaluate(Object.new)
      end.to raise_error(FixtureKit::DuplicateNameError, "Name alice already exposed")
    end

    it "stores a record as a class/id pair" do
      alice = User.create!(name: "Alice", email: "alice-pair@example.com")
      definition = described_class.new { expose(alice: alice) }

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ alice: { User => alice.id } })
    end

    it "stores a collection as an array of class/id pairs" do
      alice = User.create!(name: "Alice", email: "alice-collection@example.com")
      bob = User.create!(name: "Bob", email: "bob-collection@example.com")
      definition = described_class.new { expose(users: [alice, bob]) }

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ users: [{ User => alice.id }, { User => bob.id }] })
    end

    it "stores the record's own class for single-table-inheritance records" do
      sedan = Car.create!(name: "Sedan")
      definition = described_class.new { expose(sedan: sedan) }

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ sedan: { Car => sedan.id } })
    end

    it "raises when the record is not persisted" do
      unsaved = User.new(name: "Alice", email: "alice-unsaved@example.com")
      definition = described_class.new { expose(alice: unsaved) }

      expect { definition.evaluate(Object.new) }.to raise_error(
        FixtureKit::UnpersistedRecordError,
        /cannot expose :alice: the User is not persisted/
      )
    end

    it "raises when a record inside a collection is not persisted" do
      saved = User.create!(name: "Alice", email: "alice-mixed@example.com")
      unsaved = User.new(name: "Bob", email: "bob-mixed@example.com")
      definition = described_class.new { expose(users: [saved, unsaved]) }

      expect { definition.evaluate(Object.new) }.to raise_error(
        FixtureKit::UnpersistedRecordError,
        /cannot expose :users/
      )
    end

    it "raises when the record has been destroyed" do
      destroyed = User.create!(name: "Alice", email: "alice-destroyed@example.com")
      destroyed.destroy!
      definition = described_class.new { expose(alice: destroyed) }

      expect { definition.evaluate(Object.new) }
        .to raise_error(FixtureKit::UnpersistedRecordError)
    end

    it "allows an empty collection" do
      definition = described_class.new { expose(users: []) }

      definition.evaluate(Object.new)

      expect(definition.exposed).to eq({ users: [] })
    end

    # The registry holds every fixture for the life of the process, so a
    # definition that held its records would keep their whole object graph
    # alive until the suite ends.
    it "does not hold a reference to the exposed record" do
      alice = User.create!(name: "Alice", email: "alice-noref@example.com")
      definition = described_class.new { expose(alice: alice) }

      definition.evaluate(Object.new)

      expect(definition.exposed.values.flatten).to all(be_a(Hash))
      expect(definition.exposed.values.flatten.flat_map(&:values)).to all(be_a(Integer))
    end
  end
end
