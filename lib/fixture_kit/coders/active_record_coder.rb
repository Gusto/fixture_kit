# frozen_string_literal: true

require "active_support/notifications"
require "active_support/inflector"

module FixtureKit
  class ActiveRecordCoder < FixtureKit::Coder
    EVENT = "sql.active_record"
    NAME_PATTERN = /\A(?<model_name>.+?) (?:(?:Bulk )?(?:Insert|Upsert)|Create|Destroy|(?:Update|Delete)(?: All)?)\z/

    def generate(parent_data: nil, &block)
      captured_models = Set.new
      subscriber = lambda do |_event_name, _start, _finish, _id, payload|
        name = payload[:name].to_s
        model_name = name[NAME_PATTERN, :model_name]
        next unless model_name

        klass = ActiveSupport::Inflector.safe_constantize(model_name)
        next unless klass.is_a?(Class) && klass < ActiveRecord::Base

        captured_models.add(klass)
      end

      ActiveSupport::Notifications.subscribed(subscriber, EVENT, monotonic: true, &block)

      captured_models.map! { |model| base_table_model(model) }
      captured_models.merge(parent_data.keys) if parent_data

      generate_statements(captured_models)
    end

    def mount(data)
      models_by_pool(data).each do |pool, models|
        pool.with_connection do |connection|
          statements = models.flat_map do |model|
            [build_delete_sql(connection, model.table_name), data[model]].compact
          end

          connection.disable_referential_integrity do
            # execute_batch is private in current supported Rails versions.
            # This should be revisited when Rails 8.2 makes it public.
            connection.__send__(:execute_batch, statements, "FixtureKit Insert")
          end
        end
      end
    end

    def decode(data)
      data.transform_keys do |model_name|
        ActiveSupport::Inflector.constantize(model_name)
      end
    end

    private

    def base_table_model(model)
      model = model.superclass until model.superclass == ActiveRecord::Base || model.superclass.abstract_class?
      model
    end

    def generate_statements(models)
      models.each_with_object({}) do |model, statements|
        columns = insertable_columns(model)
        column_names = columns.map(&:name)

        rows = []
        model.unscoped.order(:id).find_each do |record|
          row_values = column_names.map do |col|
            value = record.read_attribute_before_type_cast(col)
            model.connection.quote(value)
          end
          rows << "(#{row_values.join(", ")})"
        end

        sql = rows.empty? ? nil : build_insert_sql(model.table_name, column_names, rows, model.connection)
        statements[model] = sql
      end
    end

    def insertable_columns(model)
      supports_virtual = model.connection.supports_virtual_columns?
      model.columns.reject { |c| supports_virtual && c.virtual? }
    end

    def build_delete_sql(connection, table_name)
      "DELETE FROM #{connection.quote_table_name(table_name)}"
    end

    def build_insert_sql(table_name, columns, rows, connection)
      quoted_table = connection.quote_table_name(table_name)
      quoted_columns = columns.map { |c| connection.quote_column_name(c) }

      "INSERT INTO #{quoted_table} (#{quoted_columns.join(", ")}) VALUES #{rows.join(", ")}"
    end

    def models_by_pool(data)
      seen = Set.new

      data.each_with_object({}) do |(model, _), grouped|
        pool = model.connection_pool
        next unless seen.add?([pool, model.table_name])

        grouped[pool] ||= []
        grouped[pool] << model
      end
    end
  end
end
