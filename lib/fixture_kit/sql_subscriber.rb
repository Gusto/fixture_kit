# frozen_string_literal: true

require "active_support/notifications"
require "active_support/inflector"

module FixtureKit
  class SqlSubscriber
    EVENT = "sql.active_record"
    NAME_PATTERN = /\A(?<model_name>.+?) (?:Create|Update(?: All)?)\z/

    def self.capture(&block)
      models = Set.new
      subscriber = lambda do |_event_name, _start, _finish, _id, payload|
        name = payload[:name].to_s
        model_name = name[NAME_PATTERN, :model_name]
        next unless model_name

        models.add(ActiveSupport::Inflector.constantize(model_name))
      end

      ActiveSupport::Notifications.subscribed(subscriber, EVENT, monotonic: true, &block)

      models.to_a
    end
  end
end
