# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"
require "active_support/inflector"

module FixtureKit
  class FileCache
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def exists?
      File.exist?(path)
    end

    def read
      content = JSON.parse(File.read(path))

      data = content.fetch("data").to_h do |coder_name, coder_data|
        coder = coder_for(coder_name)
        [coder.class, coder.decode(coder_data)]
      end

      exposed = content.fetch("exposed").each_with_object({}) do |(name, value), hash|
        if value.is_a?(Array)
          hash[name.to_sym] = value.map { |r| { ActiveSupport::Inflector.constantize(r.keys.first) => r.values.first } }
        else
          hash[name.to_sym] = { ActiveSupport::Inflector.constantize(value.keys.first) => value.values.first }
        end
      end

      MemoryCache.new(data: data, exposed: exposed)
    end

    def write(data)
      content = {
        data: data.data.to_h do |coder_class, coder_data|
          coder = coder_for(coder_class.name)
          [coder.class, coder.encode(coder_data)]
        end,
        exposed: data.exposed,
      }

      FileUtils.mkdir_p(File.dirname(path))
      atomically_write(JSON.pretty_generate(content))
    end

    private

    # A cache directory can be read by one process while another writes it: a
    # warm-up process filling the cache before the suite runs, a second suite
    # started against a preserved cache, or any runner whose workers share
    # `cache_path`. `File.write` truncates the destination and fills it back in,
    # so a reader that opens the file inside that window gets a prefix of the
    # JSON and fails to parse it -- a corrupt-cache failure with no corrupt cache
    # behind it. Writing a sibling file and renaming it over the destination
    # publishes the new content in one step: a concurrent reader sees either the
    # whole previous file or the whole new one, never a mixture.
    #
    # The temporary file is a sibling so the rename stays within one filesystem,
    # and carries the pid so two processes writing the same fixture cannot
    # collide on it.
    def atomically_write(payload)
      temporary_path = "#{path}.#{Process.pid}.#{SecureRandom.hex(8)}.tmp"
      File.write(temporary_path, payload)
      File.rename(temporary_path, path)
    ensure
      FileUtils.rm_f(temporary_path) if temporary_path
    end

    def coder_for(class_name)
      @coder_for ||= FixtureKit.runner.coders.index_by { |c| c.class.name }
      @coder_for.fetch(class_name)
    end
  end
end
