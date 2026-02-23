# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::RSpec::ClassMethods do
  let(:fixture_declaration) { instance_double(FixtureKit::Fixture, cache: nil) }
  let(:runner) do
    instance_double(
      FixtureKit::Runner,
      register: fixture_declaration,
      start: nil
    )
  end

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

    it "attaches a before context hook to generate cache for the declared fixture" do
      group = build_group
      group.fixture("project_management")

      expect(group.fixture_kit_before_context_hook).to be_a(Proc)
    end

    it "caches in the before context hook" do
      group = build_group
      group.fixture("project_management")

      expect(fixture_declaration).to receive(:cache)

      run_before_context_hook(group)
    end

    it "does not call runner.start in the before context hook" do
      group = build_group
      group.fixture("project_management")

      expect(runner).not_to receive(:start)
      run_before_context_hook(group)
    end
  end

  def build_group(parent_metadata = {})
    Class.new do
      extend FixtureKit::RSpec::ClassMethods

      define_singleton_method(:metadata) do
        @metadata ||= parent_metadata.dup
      end

      define_singleton_method(:prepend_before) do |scope, &block|
        raise "Unexpected scope: #{scope}" unless scope == :context

        @fixture_kit_before_context_hook = block
      end

      define_singleton_method(:fixture_kit_before_context_hook) do
        @fixture_kit_before_context_hook
      end
    end
  end

  def run_before_context_hook(group)
    group.new.instance_exec(&group.fixture_kit_before_context_hook)
  end
end
