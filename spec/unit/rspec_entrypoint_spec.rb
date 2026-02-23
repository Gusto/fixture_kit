# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::RSpec::ClassMethods do
  let(:runner) { instance_double(FixtureKit::Runner, register: :fixture_declaration) }

  before do
    allow(::RSpec.configuration).to receive(:fixture_kit).and_return(runner)
  end

  describe "#fixture" do
    it "registers named fixtures with the current example group as scope" do
      group = build_group

      group.fixture("project_management")

      expect(runner).to have_received(:register).with(group, "project_management")
    end

    it "registers anonymous fixtures with the current example group as scope" do
      group = build_group

      group.fixture { expose(example: "record") }

      expect(runner).to have_received(:register).with(group, nil)
    end

    it "allows nested groups to register their own fixtures" do
      parent_group = build_group
      child_group = build_group(parent_group.metadata)

      parent_group.fixture("project_management")
      child_group.fixture("teams/basic")

      expect(runner).to have_received(:register).with(parent_group, "project_management")
      expect(runner).to have_received(:register).with(child_group, "teams/basic")
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
