# frozen_string_literal: true

module FixtureKit
  class Definition
    attr_reader :exposed, :extends

    def initialize(extends: nil, &definition)
      @definition = definition
      @exposed = {}
      @extends = extends
    end

    def path
      @definition.source_location.first
    end

    def location
      file, line = @definition.source_location
      "#{file}:#{line}"
    end

    # Two definitions sharing a fingerprint evaluate the same block against the
    # same parent, so they are interchangeable and may share a cache entry.
    def fingerprint
      "#{location}:#{extends}"
    end

    def evaluate(context, parent: nil)
      context.singleton_class.prepend(mixin(parent))
      context.instance_exec(&@definition)
    end

    def expose(**records)
      records.each do |name, record|
        if @exposed.key?(name)
          raise FixtureKit::DuplicateNameError, "Name #{name} already exposed"
        end

        @exposed[name] = serialize(name, record)
      end
    end

    private

    def serialize(name, record)
      if record.is_a?(Array)
        record.map { |item| reference(name, item) }
      else
        reference(name, record)
      end
    end

    def reference(name, record)
      unless record.persisted?
        raise FixtureKit::UnpersistedRecordError,
          "cannot expose #{name.inspect}: the #{record.class} is not persisted. " \
          "Exposed records are captured as class/id pairs when `expose` is called, " \
          "so save the record before exposing it."
      end

      { record.class => record.id }
    end

    def mixin(parent)
      definition = self

      Module.new do
        define_method(:expose) do |**records|
          definition.expose(**records)
        end

        define_method(:parent) do
          parent
        end
      end
    end
  end
end
