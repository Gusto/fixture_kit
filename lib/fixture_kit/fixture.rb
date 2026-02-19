# frozen_string_literal: true

module FixtureKit
  ExecutionResult = Struct.new(:records, :exposed, keyword_init: true)

  class Fixture
    attr_reader :name, :block

    def initialize(name, &block)
      @name = name.to_sym
      @block = block
    end

    def execute
      tracker = RecordTracker.new

      context = FixtureContext.new(tracker)
      context.instance_eval(&block) if block

      exposed = context.exposed_metadata(tracker)

      ExecutionResult.new(records: tracker.records, exposed: exposed)
    end
  end

  class FixtureContext
    def initialize(tracker)
      @tracker = tracker
      @exposed = {}
    end

    def create(factory_name, *traits, **options)
      record = FactoryBot.create(factory_name, *traits, **options)
      @tracker.track(record, factory_name: factory_name, traits: traits)
      record
    end

    def create_list(factory_name, count, *traits, **options)
      count.times.map { create(factory_name, *traits, **options) }
    end

    def expose(**records)
      records.each do |name, record|
        name = name.to_sym

        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, <<~ERROR
            Duplicate expose name :#{name}

            A record with this name has already been exposed in this fixture.
          ERROR
        end

        if record.is_a?(Array)
          @exposed[name] = record
        else
          @tracker.rename(record, name)
          @exposed[name] = record
        end
      end
    end

    def exposed_metadata(tracker)
      metadata = {}

      @exposed.each do |name, value|
        if value.is_a?(Array)
          metadata[name] = value.map { |record| tracker.find_by_record(record).to_s }
        else
          metadata[name] = name.to_s
        end
      end

      metadata
    end
  end
end
