# frozen_string_literal: true

# This file is NOT executed by RSpec — it's parsed by Prism as test input
# for the analyzer specs. The line numbers matter for AST detection.

RSpec.describe "Orders" do
  let(:company) { create(:company) }
  let(:employee) { create(:employee) }
  let(:plain_value) { "just a string" }

  it "test 1" do; end
  it "test 2" do; end
  it "test 3" do; end

  context "with admin" do
    let(:admin) { create(:admin_user) }

    it "test 4" do; end
    it "test 5" do; end

    context "deeply nested" do
      it "test 6" do; end
    end
  end

  context "with override" do
    let(:company) { create(:company, name: "override") }

    it "test 7" do; end
    it "test 8" do; end
  end
end
