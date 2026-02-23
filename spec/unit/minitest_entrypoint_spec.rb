# frozen_string_literal: true

require "spec_helper"
require "fixture_kit/minitest"

RSpec.describe FixtureKit::Minitest::ClassMethods do
  let(:runner) { instance_double(FixtureKit::Runner, register: :fixture_declaration) }

  before do
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  describe "#fixture" do
    it "raises when called twice in the same test class" do
      test_case = build_test_case

      test_case.fixture("project_management")

      expect do
        test_case.fixture("teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same class"
      )
    end

    it "raises in subclasses when a parent class already declares a fixture" do
      parent_test_case = build_test_case
      parent_test_case.fixture("project_management")

      child_test_case = Class.new(parent_test_case)

      expect do
        child_test_case.fixture("teams/basic")
      end.to raise_error(
        FixtureKit::MultipleFixtures,
        "cannot load multiple fixtures in the same class"
      )
    end
  end

  def build_test_case
    Class.new do
      class_attribute :fixture_kit_declaration, instance_accessor: false

      extend FixtureKit::Minitest::ClassMethods
    end
  end
end
