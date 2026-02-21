# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::FixtureRegistry do
  describe ".fetch" do
    let(:fixture_path) { Rails.root.join("spec/fixture_kit").to_s }

    before do
      FixtureKit.configuration.fixture_path = fixture_path
      described_class.reset
    end

    it "raises a custom error when the fixture file does not exist" do
      expect do
        described_class.fetch("does/not_exist")
      end.to raise_error(
        FixtureKit::FixtureDefinitionNotFound,
        /Could not find fixture definition file for 'does\/not_exist'/
      )
    end
  end

end
