# frozen_string_literal: true

require "active_support/notifications"
require "active_support/inflector"

module FixtureKit
  class SqlCapture
    SQL_EVENT = "sql.active_record"

    def initialize
      @models = {}  # { Model => connection }
      @subscription = nil
    end

    def start
      @subscription = ActiveSupport::Notifications.subscribe(SQL_EVENT) do |*, payload|
        next unless payload[:sql] =~ /\AINSERT INTO/i

        # payload[:name] is like "User Create" - extract model name
        name = payload[:name]
        next unless name&.end_with?(" Create")

        model_name = name.sub(/ Create\z/, "")
        model = ActiveSupport::Inflector.constantize(model_name)
        @models[model] ||= payload[:connection]
      rescue NameError
        # Skip if model can't be found
      end
    end

    def stop
      ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
      @subscription = nil
      @models
    end
  end
end
