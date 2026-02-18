# frozen_string_literal: true

FixturyBot.define(:project_management) do
  # Primary database: Team members
  alice = create(:user, :admin, name: "Alice Chen", email: "alice@example.com")
  bob = create(:user, :manager, name: "Bob Smith", email: "bob@example.com")
  charlie = create(:user, name: "Charlie Davis", email: "charlie@example.com")

  # Primary database: Projects
  web_app = create(:project, name: "Web App Redesign", owner: alice, status: "active")
  mobile_app = create(:project, name: "Mobile App", owner: bob, status: "active")

  # Primary database: Tasks
  design_task = create(:task,
    title: "Design new homepage",
    project: web_app,
    assignee: charlie,
    status: "in_progress"
  )

  api_task = create(:task,
    title: "Build REST API",
    project: web_app,
    assignee: bob,
    status: "pending"
  )

  mobile_tasks = create_list(:task, 3, project: mobile_app, assignee: charlie)

  # Primary database: Comments
  create(:comment, body: "Looking good so far!", commentable: design_task)
  create(:comment, body: "Great progress on the project.", commentable: web_app)

  # Analytics database: Activity logs
  create(:activity_log, :task_created,
    external_user_id: alice.id,
    subject_type: "Task",
    subject_id: design_task.id,
    metadata: { project_name: web_app.name }
  )

  create(:activity_log, :task_created,
    external_user_id: bob.id,
    subject_type: "Task",
    subject_id: api_task.id
  )

  # Analytics database: Time entries
  design_time = create(:time_entry,
    external_user_id: charlie.id,
    external_task_id: design_task.id,
    hours: 4.5,
    description: "Initial wireframes",
    logged_at: 2.days.ago
  )

  api_time_entries = [
    create(:time_entry,
      external_user_id: bob.id,
      external_task_id: api_task.id,
      hours: 3.0,
      description: "API design",
      logged_at: 1.day.ago
    ),
    create(:time_entry,
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
