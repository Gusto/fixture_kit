# frozen_string_literal: true

class User < ApplicationRecord
  has_many :owned_projects, class_name: "Project", foreign_key: :owner_id
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id
  has_many :comments, as: :commentable
end
