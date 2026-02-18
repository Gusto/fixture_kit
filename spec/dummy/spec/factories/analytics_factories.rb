# frozen_string_literal: true

FactoryBot.define do
  factory :activity_log do
    external_user_id { nil }  # Set explicitly in fixtury
    action { "created" }
    subject_type { "Task" }
    subject_id { nil }
    metadata { {} }

    trait :task_created do
      action { "created" }
      subject_type { "Task" }
    end

    trait :task_completed do
      action { "completed" }
      subject_type { "Task" }
    end

    trait :comment_added do
      action { "commented" }
    end
  end

  factory :time_entry do
    external_user_id { nil }  # Set explicitly in fixtury
    external_task_id { nil }  # Set explicitly in fixtury
    hours { 2.5 }
    description { "Working on implementation" }
    logged_at { Time.current }
  end
end
