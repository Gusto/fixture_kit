# frozen_string_literal: true

module FixtureKit
  class SqlCapture
    def initialize
      @tables_by_database = Hash.new { |h, k| h[k] = Set.new }
      @subscription = nil
    end

    def start
      @subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        sql = payload[:sql]
        if sql =~ /INSERT INTO ["`]?(\w+)["`]?/i
          table_name = $1
          db_name = payload[:connection].pool.db_config.name
          @tables_by_database[db_name] << table_name
        end
      end
    end

    def stop
      ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
      @subscription = nil
      @tables_by_database
    end
  end
end
