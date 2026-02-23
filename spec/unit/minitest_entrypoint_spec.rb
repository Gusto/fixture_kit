# frozen_string_literal: true

require "spec_helper"
require "fixture_kit/minitest"

RSpec.describe FixtureKit::Minitest::ClassMethods do
  let(:runner) { instance_double(FixtureKit::Runner, register: :fixture_declaration) }

  before do
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  describe "#fixture" do
    it "registers named fixtures with the current test class as scope" do
      test_case = build_test_case

      test_case.fixture("project_management")

      expect(runner).to have_received(:register).with(test_case, "project_management")
    end

    it "registers anonymous fixtures with the current test class as scope" do
      test_case = build_test_case

      test_case.fixture { expose(example: "record") }

      expect(runner).to have_received(:register).with(test_case, nil)
    end

    it "allows subclasses to register their own fixtures" do
      parent_test_case = build_test_case
      child_test_case = Class.new(parent_test_case)

      parent_test_case.fixture("project_management")
      child_test_case.fixture("teams/basic")

      expect(runner).to have_received(:register).with(parent_test_case, "project_management")
      expect(runner).to have_received(:register).with(child_test_case, "teams/basic")
    end
  end

  def build_test_case
    Class.new do
      class_attribute :fixture_kit_declaration, instance_accessor: false

      extend FixtureKit::Minitest::ClassMethods
    end
  end
end
