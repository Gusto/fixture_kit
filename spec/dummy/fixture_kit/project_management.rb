# frozen_string_literal: true

FixtureKit.define do
  # Primary database: Team members
  alice = User.create!(name: "Alice Chen", email: "alice@example.com", role: "admin")
  bob = User.create!(name: "Bob Smith", email: "bob@example.com", role: "manager")
  charlie = User.create!(name: "Charlie Davis", email: "charlie@example.com")

  # Primary database: Projects
  web_app = Project.create!(name: "Web App Redesign", owner: alice, status: "active")
  mobile_app = Project.create!(name: "Mobile App", owner: bob, status: "active")

  # Primary database: Tasks
  design_task = Task.create!(
    title: "Design new homepage",
    project: web_app,
    assignee: charlie,
    status: "in_progress"
  )

  api_task = Task.create!(
    title: "Build REST API",
    project: web_app,
    assignee: bob,
    status: "pending"
  )

  mobile_tasks = 3.times.map do |i|
    Task.create!(title: "Mobile Task #{i + 1}", project: mobile_app, assignee: charlie)
  end

  # Primary database: Comments
  Comment.create!(body: "Looking good so far!", commentable: design_task)
  Comment.create!(body: "Great progress on the project.", commentable: web_app)

  # Analytics database: Activity logs
  ActivityLog.create!(
    action: "task_created",
    external_user_id: alice.id,
    subject_type: "Task",
    subject_id: design_task.id,
    metadata: { project_name: web_app.name }
  )

  ActivityLog.create!(
    action: "task_created",
    external_user_id: bob.id,
    subject_type: "Task",
    subject_id: api_task.id
  )

  # Analytics database: Time entries
  design_time = TimeEntry.create!(
    external_user_id: charlie.id,
    external_task_id: design_task.id,
    hours: 4.5,
    description: "Initial wireframes",
    logged_at: 2.days.ago
  )

  api_time_entries = [
    TimeEntry.create!(
      external_user_id: bob.id,
      external_task_id: api_task.id,
      hours: 3.0,
      description: "API design",
      logged_at: 1.day.ago
    ),
    TimeEntry.create!(
      external_user_id: bob.id,
      external_task_id: api_task.id,
      hours: 2.5,
      description: "Endpoint implementation",
      logged_at: Time.current
    )
  ]

  expose(
    alice: alice,
    bob: bob,
    charlie: charlie,
    web_app: web_app,
    mobile_app: mobile_app,
    design_task: design_task,
    api_task: api_task,
    mobile_tasks: mobile_tasks,
    design_time: design_time,
    api_time_entries: api_time_entries
  )
end
