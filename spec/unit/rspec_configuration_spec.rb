# frozen_string_literal: true

require "spec_helper"

RSpec.describe FixtureKit::RSpec do
  describe ".configure!" do
    let(:config) { FakeRSpecConfiguration.new }
    let(:runner) { FixtureKit::Runner.new }

    before do
      allow(FixtureKit).to receive(:runner).and_return(runner)
    end

    it "includes fixture instance methods without metadata filtering" do
      described_class.configure!(config)

      include_call = config.include_calls.find { |call| call[:module] == FixtureKit::RSpec::InstanceMethods }

      expect(include_call).not_to be_nil
      expect(include_call[:metadata]).to eq([])
    end

  end

  class FakeRSpecConfiguration
    attr_reader :include_calls

    def initialize
      @include_calls = []
    end

    def add_setting(name, default:)
      singleton_class.attr_accessor(name)
      public_send("#{name}=", default)
    end

    def extend(_mod); end

    def include(mod, *metadata)
      @include_calls << { module: mod, metadata: metadata }
    end

    def prepend_before(*_args); end

    def append_before(*_args); end

  end
end
