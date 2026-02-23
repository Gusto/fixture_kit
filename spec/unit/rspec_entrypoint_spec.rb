# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::RSpec::ClassMethods do
  let(:runner) { instance_double(FixtureKit::Runner, register: :fixture_declaration) }

  before do
    allow(::RSpec.configuration).to receive(:fixture_kit).and_return(runner)
  end

  describe "#fixture" do
    it "raises when called twice in the same example group" do
      group = build_group

      group.fixture("project_management")

      expect do
        group.fixture("teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same example group"
      )
    end

    it "raises in nested groups when parent metadata already has a fixture declaration" do
      parent_group = build_group
      parent_group.fixture("project_management")

      child_group = build_group(parent_group.metadata)

      expect do
        child_group.fixture("teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same example group"
      )
    end
  end

  def build_group(parent_metadata = {})
    Class.new do
      extend FixtureKit::RSpec::ClassMethods

      define_singleton_method(:metadata) do
        @metadata ||= parent_metadata.dup
      end
    end
  end
end
