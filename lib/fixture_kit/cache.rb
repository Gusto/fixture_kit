# frozen_string_literal: true

require "digest"

module FixtureKit
  class Cache
    ANONYMOUS_DIRECTORY = "_anonymous"
    DIGEST_LENGTH = 12

    include ConfigurationHelper

    attr_reader :fixture

    def initialize(fixture)
      @fixture = fixture
    end

    def path
      file_cache.path
    end

    def identifier
      @identifier ||= begin
        raw_identifier = fixture.identifier
        if raw_identifier.is_a?(String)
          raw_identifier
        else
          normalized_scope = FixtureKit.runner.adapter.identifier_for(raw_identifier)
          File.join(ANONYMOUS_DIRECTORY, "#{normalized_scope}.#{definition_digest}")
        end
      end
    end

    def exists?
      @content || file_cache.exists?
    end

    # The cache content, lazily read from disk and memoized. Populated by #load
    # (mount), #save, or — when neither has run in this process — by reading the
    # file cache on first access. This is what lets a child fixture pick up its
    # parent's coder data when the parent was cached to disk in a previous
    # process and has not yet been mounted. Raises if the file is absent or
    # unreadable, so callers that have not populated content must guarantee the
    # file exists (e.g. behind #exists?).
    def content
      @content ||= file_cache.read
    end

    def clear_memory
      @content = nil
    end

    def load
      unless exists?
        raise FixtureKit::CacheMissingError, "Cache does not exist for fixture '#{fixture.identifier}'"
      end

      FixtureKit.runner.coders.each do |coder|
        coder.mount(content.data_for(coder.class))
      end

      Repository.new(content.exposed)
    end

    def save
      FixtureKit.runner.adapter.execute do |context|
        @content = MemoryCache.new(
          data: evaluate(FixtureKit.runner.coders, context),
          exposed: fixture.definition.exposed
        )
      end

      file_cache.write(content)
    end

    private

    # The scope name alone does not identify a declaration site. Test
    # frameworks derive it from the group description, which is lossy -- RSpec
    # strips every non-alphanumeric character, so `Foo::Bar` and `"Foo Bar"`
    # both become `FooBar` -- and, worse, not even unique within a process:
    # test runners that load specs in batches call RSpec::Core::World#reset
    # between them, which drops the constants RSpec disambiguates against, so
    # the first group of a given description in *every* batch takes the
    # unsuffixed name. The cache directory is cleared once per process, so
    # without the digest two spec files sharing a top-level description share
    # this entry, and the second fixture to generate silently mounts the
    # first's records.
    #
    # Joined to the scope with a dot rather than an underscore: scope names are
    # snake_case, so an underscore leaves no boundary between the two, while a
    # dot cannot appear in one -- RSpec strips non-alphanumerics from the group
    # description before it is underscored.
    def definition_digest
      Digest::SHA256.hexdigest(fixture.definition.fingerprint)[0, DIGEST_LENGTH]
    end

    def evaluate(coders, context, data = {}, &block)
      if coders.empty?
        fixture.definition.evaluate(context, parent: fixture.parent&.mount)
      else
        coder, *remaining_coders = coders

        parent_data = fixture.parent ? fixture.parent.cache.content.data_for(coder.class) : nil
        data[coder.class] = coder.generate(parent_data: parent_data) do
          evaluate(remaining_coders, context, data, &block)
        end
      end

      data
    end

    def file_cache
      @file_cache ||= FileCache.new(
        File.join(configuration.cache_path, "#{identifier}.json")
      )
    end
  end
end
