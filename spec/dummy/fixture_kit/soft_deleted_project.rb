# frozen_string_literal: true

FixtureKit.define do
  owner = User.create!(name: "Project Owner", email: "owner@soft-delete.test")

  active_project = Project.create!(name: "Active Project", owner: owner)

  archived_project = Project.create!(name: "Archived Project", owner: owner)
  archived_project.update_columns(deleted_at: Time.current)

  expose(
    owner: owner,
    active_project: active_project,
    archived_project: archived_project
  )
end
