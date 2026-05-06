# frozen_string_literal: true

require "spec_helper"

# Models with generated/virtual columns can't accept INSERTs into those
# columns. The coder must filter them out when building cached statements.
RSpec.describe "Fixture round-trip with virtual columns" do
  fixture do
    ComputedWidget.create!(name: "alpha", quantity: 1)
    ComputedWidget.create!(name: "beta", quantity: 2)
  end

  after { ComputedWidget.delete_all }

  it "loads records with their generated column values" do
    widgets = ComputedWidget.order(:id).to_a

    expect(widgets.map(&:name)).to eq(["alpha", "beta"])
    expect(widgets.map(&:name_upper)).to eq(["ALPHA", "BETA"])
  end
end
