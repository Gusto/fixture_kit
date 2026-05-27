# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"

Bundler.require(*Rails.groups)

require "fixture_kit"

module Dummy
  class Application < Rails::Application
    rails_defaults_version = "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
    config.load_defaults rails_defaults_version
    config.eager_load = false

    # Set the root to the dummy directory
    config.root = File.expand_path("..", __dir__)

    # Minimal config for testing
    config.active_record.maintain_test_schema = false

    config.active_record.encryption.primary_key = "test_primary_key_32_bytes_padding"
    config.active_record.encryption.deterministic_key = "test_deterministic_key_32_padding"
    config.active_record.encryption.key_derivation_salt = "test_key_derivation_salt_padding"
  end
end
