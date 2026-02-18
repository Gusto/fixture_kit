# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { "member" }
    verified { false }

    trait :admin do
      role { "admin" }
    end

    trait :manager do
      role { "manager" }
    end

    trait :verified do
      verified { true }
    end
  end

  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    description { "A sample project description" }
    status { "active" }
    association :owner, factory: :user

    trait :completed do
      status { "completed" }
    end

    trait :archived do
      status { "archived" }
    end
  end

  factory :task do
    sequence(:title) { |n| "Task #{n}" }
    description { "A task to complete" }
    status { "pending" }
    due_date { 1.week.from_now.to_date }
    project
    association :assignee, factory: :user

    trait :in_progress do
      status { "in_progress" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :overdue do
      due_date { 1.week.ago.to_date }
    end
  end

  factory :comment do
    body { "This is a thoughtful comment." }
    association :commentable, factory: :task
  end
end
