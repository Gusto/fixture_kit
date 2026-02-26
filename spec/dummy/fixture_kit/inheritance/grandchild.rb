# frozen_string_literal: true

FixtureKit.define(extends: "inheritance/child") do
  task = Task.create!(
    title: "Inherited Task",
    project: parent.project,
    assignee: parent.project.owner
  )

  expose(task: task)
end
