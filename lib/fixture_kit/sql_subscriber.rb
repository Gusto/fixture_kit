# frozen_string_literal: true

require "active_support/notifications"
require "active_support/inflector"

module FixtureKit
  class SqlSubscriber
    EVENT = "sql.active_record"

    def self.capture(&block)
      models = Set.new
      subscriber = lambda do |_event_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        next unless sql =~ /\AINSERT INTO/i

        # payload[:name] is like "User Create" - extract model name
        name = payload[:name]
        next unless name&.end_with?(" Create")

        model_name = name.sub(/ Create\z/, "")
        models.add(ActiveSupport::Inflector.constantize(model_name))
      end

      ActiveSupport::Notifications.subscribed(subscriber, EVENT, monotonic: true, &block)

      models.to_a
    end
  end
end
