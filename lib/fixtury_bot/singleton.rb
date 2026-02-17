# frozen_string_literal: true

require "digest"
require "stringio"
require "yaml"

module FixturyBot
  module Singleton
    def configure
      @configuration = Configuration.new
      yield(@configuration) if block_given?
      self
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def define(name, &block)
      source_file = caller_locations(1, 1).first&.absolute_path
      fixtury = Fixtury.new(name, source_file: source_file, &block)
      FixturyRegistry.register(fixtury)
      fixtury
    end

    def generate(fixtury_name = nil, output: configuration.output)
      fixtury_names = fixtury_name ? [fixtury_name.to_sym] : FixturyRegistry.fixtury_names

      fixtury_names.each do |name|
        fixtury = FixturyRegistry.find(name)
        raise ArgumentError, "Fixtury '#{name}' not found" unless fixtury

        output.puts "Generating fixtury: #{name}"

        # Run setup hook if configured (e.g., to set Faker seed)
        configuration.setup&.call

        result = fixtury.execute
        generate_print_records(result, output)

        source_digest = compute_source_digest(fixtury)
        path = FixtureSerializer.new(result.records, name, configuration.fixtures_path, exposed: result.exposed, source_digest: source_digest).serialize
        output.puts "  Wrote #{result.records.size} fixtures to #{path}/"
        output.puts
      end
    end

    def validate(fixtury_name = nil)
      Validator.new(fixtury_name).validate
    end

    def load_definitions(*fixtury_names)
      @current_fixture_set = {}

      fixtury_names.each do |name|
        ensure_fixtures_available(name)
        loader = FixtureLoader.new(name, configuration.fixtures_path)
        loaded_records = loader.load
        @current_fixture_set.merge!(loaded_records)
      end

      @current_fixture_set
    end

    def current_fixture_set
      @current_fixture_set ||= {}
    end

    def clear_current_fixture_set
      @current_fixture_set = nil
    end

    def fixtury_record(name)
      current_fixture_set[name.to_sym]
    end

    def reset
      @configuration = nil
      @current_fixture_set = nil
      FixturyRegistry.reset
    end

    private

    def ensure_fixtures_available(fixtury_name)
      fixtury_name = fixtury_name.to_sym
      fixtury_path = File.join(configuration.fixtures_path, fixtury_name.to_s)
      fixtures_exist = Dir.exist?(fixtury_path)

      if fixtures_exist && !fixtures_stale?(fixtury_name)
        return
      end

      if configuration.autogenerate
        reason = fixtures_exist ? "stale" : "missing"
        $stderr.puts "[FixturyBot] Auto-generating #{reason} fixtures for :#{fixtury_name}"
        autogenerate_fixtures(fixtury_name)
      elsif fixtures_exist
        raise StaleFixturesError, <<~ERROR
          Fixtures for :#{fixtury_name} are stale (source file has changed).

          Run 'fixtury_bot generate #{fixtury_name}' to regenerate, or set config.autogenerate = true.
        ERROR
      else
        raise ArgumentError, <<~ERROR
          Fixtures for :#{fixtury_name} not found at #{fixtury_path}.

          Run 'fixtury_bot generate #{fixtury_name}' to generate, or set config.autogenerate = true.
        ERROR
      end
    end

    def fixtures_stale?(fixtury_name)
      fixtury = FixturyRegistry.find(fixtury_name)
      return false unless fixtury&.source_file

      metadata_path = File.join(configuration.fixtures_path, fixtury_name.to_s, ".fixtury_bot.yml")
      return true unless File.exist?(metadata_path)

      metadata = YAML.load_file(metadata_path, permitted_classes: [Symbol])
      stored_digest = metadata&.dig("source_digest")
      return true unless stored_digest

      current_digest = compute_source_digest(fixtury)
      return false unless current_digest

      stored_digest != current_digest
    end

    def autogenerate_fixtures(fixtury_name)
      ActiveRecord::Base.transaction do
        generate(fixtury_name, output: StringIO.new)
        raise ActiveRecord::Rollback
      end
      FactoryBot.rewind_sequences
    end

    def compute_source_digest(fixtury)
      return nil unless fixtury.source_file
      return nil unless File.exist?(fixtury.source_file)

      Digest::SHA256.file(fixtury.source_file).hexdigest
    end

    def generate_print_records(result, output)
      exposed_names = result.exposed.keys.map(&:to_sym).to_set

      result.records.each do |entry|
        factory_label = ":#{entry.factory_name}"
        factory_label += ", #{entry.traits.map { |t| ":#{t}" }.join(", ")}" if entry.traits.any?

        exposed_marker = exposed_names.include?(entry.fixture_name) ? " (exposed)" : ""

        output.puts "  create(#{factory_label}) -> #{entry.fixture_name}#{exposed_marker}"
      end

      result.exposed.each do |name, value|
        next unless value.is_a?(Array)

        output.puts "  expose(:#{name}) -> #{value.size} records"
      end
    end
  end
end
