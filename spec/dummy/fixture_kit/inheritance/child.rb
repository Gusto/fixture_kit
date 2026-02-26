# frozen_string_literal: true

FixtureKit.define(extends: "inheritance/base") do
  project = Project.create!(name: "Inherited Project", owner: parent.owner)

  expose(project: project)
end
