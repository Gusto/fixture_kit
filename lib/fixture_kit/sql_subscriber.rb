# frozen_string_literal: true

require "active_support/notifications"
require "active_support/inflector"

module FixtureKit
  class SqlSubscriber
    EVENT = "sql.active_record"
    NAME_PATTERN = /\A(?<model_name>.+?) (?:(?:Bulk )?(?:Insert|Upsert)|Create|Destroy|(?:Update|Delete)(?: All)?)\z/

    def self.capture(&block)
      models = Set.new
      subscriber = lambda do |_event_name, _start, _finish, _id, payload|
        name = payload[:name].to_s
        model_name = name[NAME_PATTERN, :model_name]
        next unless model_name

        models.add(ActiveSupport::Inflector.constantize(model_name))
      end

      ActiveSupport::Notifications.subscribed(subscriber, EVENT, monotonic: true, &block)

      models.map { |model| base_table_model(model) }.uniq
    end

    def self.base_table_model(model)
      model = model.superclass until model.superclass.abstract_class?
      model
    end
    private_class_method :base_table_model
  end
end
