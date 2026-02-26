# frozen_string_literal: true

require "spec_helper"
require "fixture_kit/minitest"

RSpec.describe FixtureKit::Minitest::ClassMethods do
  let(:fixture_declaration) { instance_double(FixtureKit::Fixture, generate: nil, mount: :repository, finish: nil) }
  let(:runner) do
    instance_double(
      FixtureKit::Runner,
      register: fixture_declaration,
      started?: false,
      start: nil
    )
  end

  before do
    allow(FixtureKit).to receive(:runner).and_return(runner)
  end

  describe "#fixture" do
    it "registers named fixtures with the current test class as scope" do
      test_case = build_test_case

      test_case.fixture("project_management")

      expect(runner).to have_received(:register).with("project_management", test_case)
    end

    it "registers anonymous fixtures with the current test class as scope" do
      test_case = build_test_case

      test_case.fixture { expose(example: "record") }

      expect(runner).to have_received(:register).with(kind_of(FixtureKit::Definition), test_case)
    end

    it "registers inherited anonymous fixtures with extends" do
      test_case = build_test_case

      test_case.fixture(extends: "teams/basic") { expose(example: "record") }

      expect(runner).to have_received(:register).with(
        an_object_having_attributes(class: FixtureKit::Definition, extends: "teams/basic"),
        test_case
      )
    end

    it "allows subclasses to register their own fixtures" do
      parent_test_case = build_test_case
      child_test_case = Class.new(parent_test_case)

      parent_test_case.fixture("project_management")
      child_test_case.fixture("teams/basic")

      expect(runner).to have_received(:register).with("project_management", parent_test_case)
      expect(runner).to have_received(:register).with("teams/basic", child_test_case)
    end
  end

  describe ".run_suite" do
    it "starts the runner and caches before running tests when the class has a fixture declaration" do
      test_case = Class.new(ActiveSupport::TestCase) do
        test "noop" do
          assert true
        end
      end
      test_case.fixture_kit_declaration = fixture_declaration
      reporter = build_reporter
      allow(test_case).to receive(:filter_runnable_methods).with({}).and_return(["test_noop"])

      expect(runner).to receive(:started?).and_return(false).ordered
      expect(runner).to receive(:start).ordered
      expect(fixture_declaration).to receive(:generate).ordered

      test_case.run_suite(reporter, {})
    ensure
      Minitest::Runnable.runnables.delete(test_case)
    end

    it "only caches before running tests when runner is already started" do
      allow(runner).to receive(:started?).and_return(true)
      test_case = Class.new(ActiveSupport::TestCase) do
        test "noop" do
          assert true
        end
      end
      test_case.fixture_kit_declaration = fixture_declaration
      reporter = build_reporter
      allow(test_case).to receive(:filter_runnable_methods).with({}).and_return(["test_noop"])

      expect(runner).not_to receive(:start)
      expect(fixture_declaration).to receive(:generate)

      test_case.run_suite(reporter, {})
    ensure
      Minitest::Runnable.runnables.delete(test_case)
    end

    it "calls finish on the declaration after tests run" do
      allow(runner).to receive(:started?).and_return(true)
      test_case = Class.new(ActiveSupport::TestCase) do
        test "noop" do
          assert true
        end
      end
      test_case.fixture_kit_declaration = fixture_declaration
      reporter = build_reporter
      allow(test_case).to receive(:filter_runnable_methods).with({}).and_return(["test_noop"])

      expect(fixture_declaration).to receive(:finish)

      test_case.run_suite(reporter, {})
    ensure
      Minitest::Runnable.runnables.delete(test_case)
    end

    it "calls finish even when there are no runnable methods" do
      test_case = Class.new(ActiveSupport::TestCase)
      test_case.fixture_kit_declaration = fixture_declaration
      reporter = build_reporter
      allow(test_case).to receive(:filter_runnable_methods).with({}).and_return([])

      expect(fixture_declaration).to receive(:finish)

      test_case.run_suite(reporter, {})
    ensure
      Minitest::Runnable.runnables.delete(test_case)
    end

    it "does not start or cache when there are no runnable methods" do
      test_case = Class.new(ActiveSupport::TestCase)
      test_case.fixture_kit_declaration = fixture_declaration
      reporter = build_reporter
      allow(test_case).to receive(:filter_runnable_methods).with({}).and_return([])

      expect(runner).not_to receive(:start)
      expect(fixture_declaration).not_to receive(:generate)

      test_case.run_suite(reporter, {})
    ensure
      Minitest::Runnable.runnables.delete(test_case)
    end
  end

  def build_test_case
    Class.new do
      class_attribute :fixture_kit_declaration, instance_accessor: false

      extend FixtureKit::Minitest::ClassMethods
    end
  end

  def build_reporter
    Class.new do
      def prerecord(_klass, _method_name); end

      def record(_result); end
    end.new
  end
end
