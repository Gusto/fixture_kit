# frozen_string_literal: true

RSpec.describe FixturyBot::FixturyRegistry do
  describe ".register" do
    it "stores a fixtury" do
      fixtury = FixturyBot::Fixtury.new(:test_fixtury) { }

      described_class.register(fixtury)

      expect(described_class.find(:test_fixtury)).to eq(fixtury)
    end
  end

  describe ".find" do
    it "returns nil for non-existent fixturys" do
      expect(described_class.find(:nonexistent)).to be_nil
    end

    it "accepts string or symbol" do
      fixtury = FixturyBot::Fixtury.new(:string_test) { }
      described_class.register(fixtury)

      expect(described_class.find("string_test")).to eq(fixtury)
      expect(described_class.find(:string_test)).to eq(fixtury)
    end
  end

  describe ".fixtury_names" do
    it "returns all registered fixtury names" do
      described_class.register(FixturyBot::Fixtury.new(:first) { })
      described_class.register(FixturyBot::Fixtury.new(:second) { })

      expect(described_class.fixtury_names).to contain_exactly(:first, :second)
    end
  end

  describe ".reset" do
    it "clears all fixturys" do
      described_class.register(FixturyBot::Fixtury.new(:to_clear) { })

      described_class.reset

      expect(described_class.find(:to_clear)).to be_nil
      expect(described_class.fixtury_names).to be_empty
    end
  end
end
