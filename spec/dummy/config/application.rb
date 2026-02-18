# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"

Bundler.require(*Rails.groups)

require "fixtury_bot"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false

    # Set the root to the dummy directory
    config.root = File.expand_path("..", __dir__)

    # Minimal config for testing
    config.active_record.maintain_test_schema = false
  end
end
