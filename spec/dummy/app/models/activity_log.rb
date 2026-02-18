# frozen_string_literal: true

class ActivityLog < AnalyticsRecord
  # Soft foreign key to primary.users - cannot use belongs_to across databases
  # external_user_id references the user who performed the action
  # subject_type/subject_id are polymorphic-like references to primary records
end
