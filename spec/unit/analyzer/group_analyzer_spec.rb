# frozen_string_literal: true

require "fixture_kit/analyzer"
require_relative "../../support/analyzer_helpers"

RSpec.describe FixtureKit::Analyzer::GroupAnalyzer do
  include AnalyzerHelpers

  let(:sample_spec) { File.expand_path("../../fixtures/analyzer/sample_spec.rb", __dir__) }

  describe "#examples_using_let" do
    it "counts examples in the defining group" do
      group = AnalyzerHelpers::FakeGroup.new(description: "root", examples: 3)
      analyzer = described_class.new

      expect(analyzer.examples_using_let(group, "company")).to eq(3)
    end

    it "counts examples in child groups that inherit the let" do
      child = AnalyzerHelpers::FakeGroup.new(description: "child", examples: 2)
      root = AnalyzerHelpers::FakeGroup.new(description: "root", examples: 3, children: [child])
      analyzer = described_class.new

      expect(analyzer.examples_using_let(root, "company")).to eq(5)
    end

    it "stops counting at child groups that override the let" do
      overriding_child = AnalyzerHelpers::FakeGroup.new(
        description: "override",
        examples: 2,
        lets: {company: {file: sample_spec, line: 27}},
      )
      root = AnalyzerHelpers::FakeGroup.new(
        description: "root",
        examples: 3,
        lets: {company: {file: sample_spec, line: 7}},
        children: [overriding_child],
      )
      analyzer = described_class.new

      expect(analyzer.examples_using_let(root, "company")).to eq(3)
    end

    it "counts through non-overriding nested children" do
      grandchild = AnalyzerHelpers::FakeGroup.new(description: "grandchild", examples: 1)
      child = AnalyzerHelpers::FakeGroup.new(description: "child", examples: 2, children: [grandchild])
      root = AnalyzerHelpers::FakeGroup.new(description: "root", examples: 3, children: [child])
      analyzer = described_class.new

      expect(analyzer.examples_using_let(root, "company")).to eq(6)
    end
  end

  describe "#total_examples" do
    it "sums examples across the entire tree" do
      grandchild = AnalyzerHelpers::FakeGroup.new(description: "grandchild", examples: 1)
      child1 = AnalyzerHelpers::FakeGroup.new(description: "child1", examples: 2, children: [grandchild])
      child2 = AnalyzerHelpers::FakeGroup.new(description: "child2", examples: 4)
      root = AnalyzerHelpers::FakeGroup.new(description: "root", examples: 3, children: [child1, child2])
      analyzer = described_class.new

      expect(analyzer.total_examples(root)).to eq(10)
    end
  end

  describe "#analyze" do
    it "collects factory lets with correct example counts" do
      child_with_admin = AnalyzerHelpers::FakeGroup.new(
        description: "with admin",
        examples: 2,
        lets: {admin: {file: sample_spec, line: 16}},
        children: [
          AnalyzerHelpers::FakeGroup.new(description: "deeply nested", examples: 1),
        ],
      )
      child_with_override = AnalyzerHelpers::FakeGroup.new(
        description: "with override",
        examples: 2,
        lets: {company: {file: sample_spec, line: 27}},
      )
      root = AnalyzerHelpers::FakeGroup.new(
        description: "Orders",
        file_path: sample_spec,
        examples: 3,
        lets: {
          company: {file: sample_spec, line: 7},
          employee: {file: sample_spec, line: 8},
          plain_value: {file: sample_spec, line: 9},
        },
        children: [child_with_admin, child_with_override],
      )

      analyzer = described_class.new
      results = analyzer.analyze(root)

      # plain_value has no factory calls, so it's excluded
      factory_let_names = results.map(&:name).sort
      expect(factory_let_names).to eq(["admin", "company", "company", "employee"])

      # Root company: 3 own + 2 admin child + 1 deeply nested = 6 (override child excluded)
      root_company = results.find { |r| r.name == "company" && r.group_description == "Orders" }
      expect(root_company.example_count).to eq(6)
      expect(root_company.factories).to eq(["company"])

      # Override company: 2 own examples
      override_company = results.find { |r| r.name == "company" && r.group_description == "with override" }
      expect(override_company.example_count).to eq(2)

      # Employee: 3 own + 2 admin + 1 deeply nested + 2 override = 8 (no one overrides employee)
      employee = results.find { |r| r.name == "employee" }
      expect(employee.example_count).to eq(8)

      # Admin: 2 own + 1 deeply nested = 3
      admin = results.find { |r| r.name == "admin" }
      expect(admin.example_count).to eq(3)
      expect(admin.factories).to eq(["admin_user"])
    end
  end
end
