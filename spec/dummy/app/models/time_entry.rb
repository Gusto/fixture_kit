# frozen_string_literal: true

class TimeEntry < AnalyticsRecord
  # Soft foreign keys to primary database - cannot use belongs_to across databases
  # external_user_id references the user who logged time
  # external_task_id references the task being worked on
end
