# frozen_string_literal: true

FixtureKit.define do
  now = Time.current

  User.insert_all!([
    {
      name: "Event User",
      email: "event.user@example.com",
      role: "member",
      verified: false,
      created_at: now,
      updated_at: now
    }
  ])
  user = User.find_by!(email: "event.user@example.com")
  user.update!(name: "Event User Updated")

  Project.insert_all!([
    {
      name: "Event Project",
      description: "Seeded for query event coverage",
      status: "active",
      owner_id: user.id,
      created_at: now,
      updated_at: now
    }
  ])
  Project.where(name: "Event Project").update_all(status: "archived")
  project = Project.find_by!(name: "Event Project")

  Task.insert_all!([
    {
      title: "Event Task",
      description: "Seeded for destroy coverage",
      status: "pending",
      due_date: Date.current,
      project_id: project.id,
      assignee_id: user.id,
      created_at: now,
      updated_at: now
    }
  ])
  Task.find_by!(title: "Event Task").destroy!

  comment = Comment.create!(body: "Created during fixture generation", commentable: project)

  ActivityLog.insert_all!([
    {
      external_user_id: user.id,
      action: "delete_me",
      subject_type: "Project",
      subject_id: project.id,
      metadata: { source: "fixture_kit" },
      created_at: now,
      updated_at: now
    },
    {
      external_user_id: user.id,
      action: "keep_me",
      subject_type: "Project",
      subject_id: project.id,
      metadata: { source: "fixture_kit" },
      created_at: now,
      updated_at: now
    }
  ])
  ActivityLog.where(action: "delete_me").delete_all

  expose(
    user: user,
    project: project,
    comment: comment
  )
end
